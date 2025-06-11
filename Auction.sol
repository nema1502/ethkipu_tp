// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Auction
 * @dev A decentralized auction contract where users can bid on an item.
 * The highest bidder wins, and non-winners can claim their refunds.
 */
contract Auction {
    address public owner;
    uint public auctionEndTime;
    string public itemDescription;
    uint public highestBid;
    address public highestBidder;
    // Maps bidder address to their total deposited amount
    mapping(address => uint) public deposits;
    // Maps bidder address to their current active bid amount (could be less than deposit if partial withdrawal occurred)
    mapping(address => uint) public bids;

    bool public auctionEnded;

    // A list of addresses that have placed bids, used for efficient iteration for refunds.
    address[] private bidders;
    // A mapping to check if an address is already in the bidders array.
    mapping(address => bool) private hasBid;

    event NewOffer(address indexed bidder, uint amount);
    event AuctionEnded(address indexed winner, uint winningBid);
    event DepositRefunded(address indexed bidder, uint amount);
    event PartialRefund(address indexed bidder, uint amount);
    event EmergencyEthRecovered(uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "OWNER_ONLY");
        _;
    }

    modifier auctionNotEnded() {
        require(block.timestamp < auctionEndTime, "AUCTION_ENDED");
        _;
    }

    modifier auctionEndedModifier() {
        require(block.timestamp >= auctionEndTime && !auctionEnded, "AUCTION_NOT_ENDED_OR_ALREADY_FINALIZED");
        _;
    }

    /**
     * @dev Constructor to initialize the auction.
     * @param _auctionDurationInMinutes The duration of the auction in minutes.
     * @param _itemDescription A brief description of the item being auctioned.
     */
    constructor(uint _auctionDurationInMinutes, string memory _itemDescription) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_auctionDurationInMinutes * 1 minutes);
        itemDescription = _itemDescription;
        highestBid = 0;
        auctionEnded = false;
    }

    /**
     * @dev Allows users to place a bid on the item.
     * The bid must be at least 5% higher than the current highest bid.
     * If a bid is placed within the last 10 minutes, the auction end time is extended by 10 minutes.
     * The `payable` keyword allows the function to receive Ether.
     */
    function bid() public payable auctionNotEnded {
        // Requires should always be at the top
        require(msg.value > 0, "BID_AMOUNT_ZERO");

        uint currentHighestBid = highestBid; // Read state variable once
        uint minimumNextBid = currentHighestBid + (currentHighestBid / 20);

        // If no bids yet, minimum bid is 1 wei.
        if (currentHighestBid == 0) {
            minimumNextBid = 1;
        }

        require(msg.value >= minimumNextBid, "BID_TOO_LOW");

        // Add bidder to the list if they are new.
        if (!hasBid[msg.sender]) {
            bidders.push(msg.sender);
            hasBid[msg.sender] = true;
        }

        // Extend auction if within 10 minutes of end and there's a highest bid.
        if (block.timestamp + 10 minutes >= auctionEndTime && currentHighestBid > 0) {
            auctionEndTime += 10 minutes;
        }

        // Update deposits and bids. Avoid writing to state variables multiple times.
        deposits[msg.sender] += msg.value;
        bids[msg.sender] = msg.value; // Store the actual bid value

        // Update highest bid and bidder if current bid is higher.
        if (msg.value > currentHighestBid) {
            highestBid = msg.value; // Write state variable once
            highestBidder = msg.sender; // Write state variable once
        }

        emit NewOffer(msg.sender, msg.value);
    }

    /**
     * @dev Allows a bidder to withdraw any excess Ether they have deposited
     * that is above their current active bid. This is a partial withdrawal.
     */
    function withdrawExcessDeposit() public auctionNotEnded {
        // Read state variables once
        uint senderDeposit = deposits[msg.sender];
        uint senderBid = bids[msg.sender];

        require(senderDeposit > senderBid, "NO_EXCESS_DEPOSIT");

        uint amountToRefund = senderDeposit - senderBid;
        deposits[msg.sender] = senderBid; // Update state variable once

        (bool success, ) = msg.sender.call{value: amountToRefund}("");
        require(success, "REFUND_FAILED");
        emit PartialRefund(msg.sender, amountToRefund);
    }

    /**
     * @dev Ends the auction and sets the `auctionEnded` flag.
     * Can only be called by the owner after the auction end time.
     * @return true if the auction was successfully ended.
     */
    function endAuction() public onlyOwner auctionEndedModifier returns (bool) {
        require(highestBidder != address(0), "NO_BIDS_MADE");
        auctionEnded = true; // Write state variable once
        emit AuctionEnded(highestBidder, highestBid);
        return true;
    }

    /**
     * @dev Displays the winner and their winning bid after the auction has ended.
     * @return winner The address of the winning bidder.
     * @return winningBid The amount of the winning bid.
     */
    function showWinner() public view returns (address winner, uint winningBid) {
        require(auctionEnded, "AUCTION_NOT_ENDED");
        return (highestBidder, highestBid);
    }

    /**
     * @dev Returns the bid amount placed by a specific bidder.
     * @param _bidder The address of the bidder.
     * @return The bid amount of the specified bidder.
     */
    function getBidOf(address _bidder) public view returns (uint) {
        return bids[_bidder];
    }

    /**
     * @dev Allows non-winning bidders to refund their deposits.
     * A 2% commission is applied to the refund amount.
     * This function can only be called after the auction has ended.
     */
    function refundDeposit() public {
        // Requires should always be at the top
        require(auctionEnded, "AUCTION_NOT_ENDED");
        require(msg.sender != highestBidder, "WINNER_CANNOT_REFUND");

        uint senderDeposit = deposits[msg.sender]; // Read state variable once
        require(senderDeposit > 0, "NO_DEPOSIT_TO_REFUND");

        uint commission = (senderDeposit * 2) / 100;
        uint netRefundAmount = senderDeposit - commission;

        deposits[msg.sender] = 0; // Write state variable once

        (bool success, ) = msg.sender.call{value: netRefundAmount}("");
        require(success, "REFUND_FAILED");
        emit DepositRefunded(msg.sender, netRefundAmount);
    }

    /**
     * @dev Distributes the ethers corresponding to all non-winning offers
     * using a loop to iterate over them. This function should ideally be called
     * after the auction has ended and is intended to streamline refunds for non-winners.
     * This function can be called by anyone but only processes eligible refunds.
     */
    function distributeNonWinnerRefunds() public {
        require(auctionEnded, "AUCTION_NOT_ENDED");

        uint initialBiddersLength = bidders.length; // Declare outside the loop (dirty variable)
        address currentBidder; // Declare outside the loop (dirty variable)
        uint senderDeposit; // Declare outside the loop (dirty variable)
        uint commission; // Declare outside the loop (dirty variable)
        uint netRefundAmount; // Declare outside the loop (dirty variable)

        // Iterate through the list of all bidders.
        for (uint i = 0; i < initialBiddersLength; i++) {
            currentBidder = bidders[i]; // Read from array once per iteration

            // Skip if the bidder is the winner or has already been refunded
            if (currentBidder == highestBidder || deposits[currentBidder] == 0) {
                continue;
            }

            senderDeposit = deposits[currentBidder]; // Read state variable once
            commission = (senderDeposit * 2) / 100;
            netRefundAmount = senderDeposit - commission;

            deposits[currentBidder] = 0; // Write state variable once

            // Attempt to send the refund. Handle potential failures gracefully.
            (bool success, ) = currentBidder.call{value: netRefundAmount}("");
            if (!success) {
                // Log failure but don't revert the entire transaction
                // Consider adding an event here for failed refunds to track them.
            } else {
                emit DepositRefunded(currentBidder, netRefundAmount);
            }
        }
    }

    /**
     * @dev Allows the owner to withdraw all funds from the contract after the auction has ended.
     */
    function withdrawFunds() public onlyOwner {
        require(auctionEnded, "AUCTION_NOT_ENDED");
        require(highestBidder != address(0), "NO_WINNER_TO_WITHDRAW_FUNDS");

        uint totalFunds = address(this).balance; // Read contract balance once
        require(totalFunds > 0, "NO_FUNDS_TO_WITHDRAW"); // Check if there are funds to withdraw

        (bool success, ) = owner.call{value: totalFunds}("");
        require(success, "FUNDS_TRANSFER_FAILED");
    }

    /**
     * @dev Emergency function to recover accidentally sent Ether to the contract.
     * Only the owner can call this.
     */
    function emergencyEthRecovery() public onlyOwner {
        uint contractBalance = address(this).balance; // Read contract balance once
        require(contractBalance > 0, "NO_ETH_TO_RECOVER");

        (bool success, ) = owner.call{value: contractBalance}("");
        require(success, "EMERGENCY_RECOVERY_FAILED");
        emit EmergencyEthRecovered(contractBalance);
    }

    /**
     * @dev Fallback function to receive Ether.
     * This allows the contract to receive Ether directly.
     */
    receive() external payable {
        // This function is executed when Ether is sent to the contract
        // without any data or when a non-existent function is called.
    }
}
