// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IDutchAuction} from "../interface/IDutchAuction.sol";
import {IEscrow} from "../interface/IEscrow.sol";
import {IAgentRequester, IJsonApiAgent} from "../interface/IDataProvider.sol";


contract DataProvider {
    enum ConsensusType {
        Majority,
        Threshold
    }

    enum ResponseStatus {
        None,
        Pending,
        Success,
        Failed,
        TimedOut
    }

    struct Response {
        address validator;
        bytes result;
        ResponseStatus status;
        uint256 receipt;
        uint256 timestamp;
        uint256 executionCost;
    }

    struct Request {
        uint256 id;
        address requester;
        address callbackAddress;
        bytes4 callbackSelector;
        address[] subcommittee;
        Response[] responses;
        uint256 responseCount;
        uint256 failureCount;
        uint256 threshold;
        uint256 createdAt;
        uint256 deadline;
        ResponseStatus status;
        ConsensusType consensusType;
        uint256 remainingBudget;
        uint256 perAgentBudget;
    }

    error OnlyProvider();
    error OnlyPlatform();
    error AuctionNotSnapped();
    error InsufficientAgentCallDeposit();
    error UnknownRequest();
    error ZeroAddress();
    error InvalidAgentId();
    error RefundFailed();

    uint256 public constant SUBCOMMITTEE_SIZE = 3;
    uint256 public constant PER_AGENT_EXECUTION_COST = 0.03 ether;

    IAgentRequester public platform;
    uint256 public jsonApiAgentId;
    IEscrow public escrow;
    IDutchAuction public dutchAuction;

    mapping(uint256 => uint256) public requestToAuction;
    mapping(uint256 => bool) public pendingRequests;

    event DataRequested(uint256 indexed auctionId, uint256 indexed requestId);
    event DataDelivered(
        uint256 indexed auctionId,
        address indexed consumer,
        uint256 price,
        uint256 timestamp
    );
    event DataFailed(uint256 indexed auctionId, uint8 status);

    constructor(
        address platform_,
        uint256 jsonApiAgentId_,
        address escrow_,
        address dutchAuction_
    ) {
        if (
            platform_ == address(0) ||
            escrow_ == address(0) ||
            dutchAuction_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (jsonApiAgentId_ == 0) revert InvalidAgentId();

        platform = IAgentRequester(platform_);
        jsonApiAgentId = jsonApiAgentId_;
        escrow = IEscrow(escrow_);
        dutchAuction = IDutchAuction(dutchAuction_);
    }

    function fulfillOrder(uint256 auctionId) external payable {
        IDutchAuction.Auction memory auction_ = dutchAuction.getAuction(
            auctionId
        );
        if (auction_.status != IDutchAuction.AuctionStatus.Snapped)
            revert AuctionNotSnapped();
        if (msg.sender != auction_.provider) revert OnlyProvider();

        uint256 reserve = platform.getRequestDeposit();
        uint256 reward = PER_AGENT_EXECUTION_COST * SUBCOMMITTEE_SIZE;
        uint256 deposit = reserve + reward;
        if (msg.value < deposit) revert InsufficientAgentCallDeposit();

        bytes memory payload = abi.encodeWithSelector(
            IJsonApiAgent.fetchUint.selector,
            auction_.apiUrl,
            auction_.jsonSelector,
            auction_.decimals
        );

        uint256 requestId = platform.createRequest{value: deposit}(
            jsonApiAgentId,
            address(this),
            this.handleResponse.selector,
            payload
        );

        requestToAuction[requestId] = auctionId;
        pendingRequests[requestId] = true;

        uint256 refund = msg.value - deposit;
        if (refund != 0) {
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert RefundFailed();
        }

        emit DataRequested(auctionId, requestId);
    }

    function handleResponse(
        uint256 requestId,
        Response[] memory responses,
        ResponseStatus status,
        Request memory
    ) external {
        if (msg.sender != address(platform)) revert OnlyPlatform();
        if (!pendingRequests[requestId]) revert UnknownRequest();

        delete pendingRequests[requestId];
        uint256 auctionId = requestToAuction[requestId];

        if (status != ResponseStatus.Success || responses.length == 0) {
            emit DataFailed(auctionId, uint8(status));
            return;
        }

        uint256 price = abi.decode(responses[0].result, (uint256));
        escrow.release(auctionId);

        IDutchAuction.Auction memory auction_ = dutchAuction.getAuction(
            auctionId
        );
        emit DataDelivered(auctionId, auction_.winner, price, block.timestamp);
    }

    receive() external payable {}
}
