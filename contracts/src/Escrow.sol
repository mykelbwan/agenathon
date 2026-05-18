// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract Escrow {
    enum EscrowStatus {
        Empty,
        Locked,
        Released,
        Refunded
    }

    struct EscrowRecord {
        address buyer;
        address provider;
        uint256 amount;
        uint256 lockedAtBlock;
        uint256 timeoutBlocks;
        EscrowStatus status;
    }

    error OnlyOwner();
    error OnlyDataProvider();
    error DataProviderAlreadySet();
    error ZeroAddress();
    error RecordAlreadyExists();
    error NoPayment();
    error InvalidTimeout();
    error RecordNotLocked();
    error OnlyBuyer();
    error TimeoutNotReached();
    error TransferFailed();

    mapping(uint256 => EscrowRecord) public records;

    address public owner;
    address public dataProvider;

    event DataProviderSet(address indexed dataProvider);
    event PaymentLocked(
        uint256 indexed auctionId,
        address buyer,
        address provider,
        uint256 amount
    );
    event PaymentReleased(
        uint256 indexed auctionId,
        address provider,
        uint256 amount
    );
    event PaymentRefunded(
        uint256 indexed auctionId,
        address buyer,
        uint256 amount
    );

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    modifier onlyDataProvider() {
        _onlyDataProvider();
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert OnlyOwner();
    }

    function _onlyDataProvider() internal view {
        if (msg.sender != dataProvider) revert OnlyDataProvider();
    }

    function setDataProvider(address dataProvider_) external onlyOwner {
        if (dataProvider != address(0)) revert DataProviderAlreadySet();
        if (dataProvider_ == address(0)) revert ZeroAddress();

        dataProvider = dataProvider_;
        emit DataProviderSet(dataProvider_);
    }

    function lockPayment(
        uint256 auctionId,
        address buyer,
        address provider,
        uint256 timeoutBlocks
    ) external payable {
        if (records[auctionId].status != EscrowStatus.Empty)
            revert RecordAlreadyExists();
        if (msg.value == 0) revert NoPayment();
        if (buyer == address(0) || provider == address(0)) revert ZeroAddress();
        if (timeoutBlocks == 0) revert InvalidTimeout();

        records[auctionId] = EscrowRecord({
            buyer: buyer,
            provider: provider,
            amount: msg.value,
            lockedAtBlock: block.number,
            timeoutBlocks: timeoutBlocks,
            status: EscrowStatus.Locked
        });

        emit PaymentLocked(auctionId, buyer, provider, msg.value);
    }

    function release(uint256 auctionId) external onlyDataProvider {
        EscrowRecord storage record = records[auctionId];
        if (record.status != EscrowStatus.Locked) revert RecordNotLocked();

        record.status = EscrowStatus.Released;
        (bool success, ) = payable(record.provider).call{value: record.amount}(
            ""
        );
        if (!success) revert TransferFailed();

        emit PaymentReleased(auctionId, record.provider, record.amount);
    }

    function claimRefund(uint256 auctionId) external {
        EscrowRecord storage record = records[auctionId];
        if (record.status != EscrowStatus.Locked) revert RecordNotLocked();
        if (msg.sender != record.buyer) revert OnlyBuyer();
        if (block.number <= record.lockedAtBlock + record.timeoutBlocks)
            revert TimeoutNotReached();

        record.status = EscrowStatus.Refunded;
        (bool success, ) = payable(record.buyer).call{value: record.amount}("");
        if (!success) revert TransferFailed();

        emit PaymentRefunded(auctionId, record.buyer, record.amount);
    }
}
