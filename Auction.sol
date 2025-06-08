// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Auction {
    address public owner;
    uint public auctionEndTime;
    string public itemDescription;
    uint public highestBid;
    address public highestBidder;
    mapping(address => uint) public bids;
    mapping(address => uint) public deposits;

    bool public auctionEnded;

    event NewOffer(address indexed bidder, uint amount);
    event AuctionEnded(address indexed winner, uint winningBid);
    event DepositRefunded(address indexed bidder, uint amount);
    event PartialRefund(address indexed bidder, uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede llamar a esta funcion");
        _;
    }

    modifier auctionNotEnded() {
        require(block.timestamp < auctionEndTime, "La subasta ha terminado");
        _;
    }

    modifier auctionEndedModifier() {
        require(block.timestamp >= auctionEndTime && !auctionEnded, "La subasta no ha terminado o ya se finalizo");
        _;
    }

    constructor(uint _auctionDurationInMinutes, string memory _itemDescription) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + (_auctionDurationInMinutes * 1 minutes);
        itemDescription = _itemDescription;
        highestBid = 0;
        auctionEnded = false;
    }

    function bid() public payable auctionNotEnded {
        uint minimumNextBid = highestBid + (highestBid / 20);

        if (highestBid == 0) {
            minimumNextBid = 1;
        }

        require(msg.value >= minimumNextBid, "La oferta debe ser al menos 5% mayor que la oferta actual mas alta");

        if (block.timestamp + 10 minutes >= auctionEndTime && highestBid > 0) {
            auctionEndTime += 10 minutes;
        }

        deposits[msg.sender] += msg.value;
        bids[msg.sender] = msg.value;

        if (msg.value > highestBid) {
            highestBid = msg.value;
            highestBidder = msg.sender;
        }

        emit NewOffer(msg.sender, msg.value);
    }

    function withdrawExcessDeposit() public auctionNotEnded {
        require(deposits[msg.sender] > bids[msg.sender], "No hay exceso de deposito para retirar");

        uint amountToRefund = deposits[msg.sender] - bids[msg.sender];
        deposits[msg.sender] = bids[msg.sender];

        (bool success, ) = msg.sender.call{value: amountToRefund}("");
        require(success, "Fallo al enviar el exceso de deposito");
        emit PartialRefund(msg.sender, amountToRefund);
    }

    function endAuction() public onlyOwner auctionEndedModifier {
        require(highestBidder != address(0), "No se realizaron ofertas");
        auctionEnded = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    function showWinner() public view returns (address, uint) {
        require(auctionEnded, "La subasta aun no ha terminado");
        return (highestBidder, highestBid);
    }

    function getBidOf(address _bidder) public view returns (uint) {
        return bids[_bidder];
    }

    function refundDeposit() public {
        require(auctionEnded, "La subasta aun no ha terminado");
        require(msg.sender != highestBidder, "El ganador no puede obtener un reembolso");
        require(deposits[msg.sender] > 0, "No hay deposito para reembolsar");

        uint amountToRefund = deposits[msg.sender];
        uint commission = (amountToRefund * 2) / 100;
        uint netRefundAmount = amountToRefund - commission;

        deposits[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: netRefundAmount}("");
        require(success, "Fallo al enviar el reembolso");
        emit DepositRefunded(msg.sender, netRefundAmount);
    }

    function withdrawFunds() public onlyOwner {
        require(auctionEnded, "La subasta aun no ha terminado");
        require(highestBidder != address(0), "No hay ganador para retirar fondos");

        uint totalFunds = address(this).balance;

        (bool success, ) = owner.call{value: totalFunds}("");
        require(success, "Fallo al transferir fondos al propietario");
    }

    receive() external payable {
    }
}