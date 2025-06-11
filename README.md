# Auction Smart Contract

This document provides a comprehensive overview of the `Auction` smart contract, including its functionality, deployment, and how to interact with it.

---

## Table of Contents

-   [Contract Overview](#contract-overview)
-   [Features](#features)
-   [Deployment](#deployment)
-   [Functions](#functions)
    -   [Constructor](#constructor)
    -   [bid](#bid)
    -   [withdrawExcessDeposit](#withdrawexcessdeposit)
    -   [endAuction](#endauction)
    -   [showWinner](#showwinner)
    -   [getBidOf](#getbidof)
    -   [refundDeposit](#refunddeposit)
    -   [distributeNonWinnerRefunds](#distributenonwinnerrefunds)
    -   [withdrawFunds](#withdrawfunds)
    -   [emergencyEthRecovery](#emergencyethrecovery)
    -   [receive](#receive)
-   [Events](#events)
-   [Error Handling](#error-handling)
-   [Usage Example](#usage-example)

---

## Contract Overview

The `Auction` smart contract is a decentralized application that facilitates an auction process on the Ethereum blockchain. Users can place bids on a specific item, and the highest bidder wins. Non-winning bidders can claim their deposited Ether back, minus a small commission. The contract also includes features for partial withdrawals, emergency fund recovery, and an owner-controlled auction ending mechanism.

---

## Features

* **Secure Bidding:** Users can place bids, with a minimum increment to ensure competitive bidding.
* **Auction Extension:** The auction end time automatically extends if a bid is placed near the end of the auction, preventing "sniping."
* **Partial Withdrawals:** Bidders can withdraw any excess Ether they've deposited that isn't actively part of their bid.
* **Automated Refunds for Non-Winners:** A dedicated function allows for the distribution of refunds to all non-winning bidders.
* **Owner-Controlled Auction Ending:** The contract owner has the authority to officially end the auction.
* **Emergency ETH Recovery:** A safeguard function allows the owner to recover any Ether accidentally sent directly to the contract.
* **Gas Optimization:** The code is optimized for gas efficiency through practices like short `require` strings, single state variable reads/writes, and "dirty" variable usage in loops.

---

## Deployment

To deploy this contract, you'll need a Solidity development environment (e.g., Remix, Hardhat, Truffle).

1.  **Compile the Contract:** Compile the `Auction.sol` file using a Solidity compiler version `0.8.20` or higher.
2.  **Deploy:** Deploy the compiled bytecode to an Ethereum network (e.g., Sepolia, Goerli, or a local development network).
    * The **constructor** requires two arguments:
        * `_auctionDurationInMinutes` (uint): The duration of the auction in minutes.
        * `_itemDescription` (string memory): A brief description of the item being auctioned.

---

## Functions

### Constructor

```solidity
constructor(uint _auctionDurationInMinutes, string memory _itemDescription)
