// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IDutchAuction {
    enum AuctionStatus {
        Active,
        Snapped,
        Expired
    }

    struct Auction {
        uint256 id;
        address provider;
        string dataType;
        string apiUrl;
        string jsonSelector;
        uint8 decimals;
        uint256 startPrice;
        uint256 floorPrice;
        uint256 currentPrice;
        uint256 priceStep;
        uint256 startBlock;
        uint256 timeoutBlocks;
        AuctionStatus status;
        address winner;
        uint256 escrowRef;
    }

    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed provider,
        string dataType,
        uint256 startPrice
    );
    event PriceTick(
        uint256 indexed auctionId,
        uint256 newPrice,
        uint256 blockNumber
    );
    event AuctionSnapped(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice
    );
    event AuctionExpired(uint256 indexed auctionId);

    function startAuction(
        string calldata dataType,
        string calldata apiUrl,
        string calldata jsonSelector,
        uint8 decimals,
        uint256 startPrice,
        uint256 floorPrice,
        uint256 priceStep,
        uint256 timeoutBlocks
    ) external returns (uint256 auctionId);

    function dropPrice(uint256 auctionId) external;

    function snap(uint256 auctionId) external payable returns (bool);

    function getActiveAuctions() external view returns (uint256[] memory);

    function getAuction(
        uint256 auctionId
    ) external view returns (Auction memory);
}
