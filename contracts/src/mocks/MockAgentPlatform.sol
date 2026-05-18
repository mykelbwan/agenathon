// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract MockAgentPlatform {
    uint256 public nextRequestId = 1;
    uint256 public requestDeposit = 0.03 ether;

    event RequestCreated(
        uint256 indexed requestId,
        uint256 indexed agentId,
        address indexed callbackAddress,
        bytes4 callbackSelector,
        bytes payload,
        uint256 deposit
    );

    function createRequest(
        uint256 agentId,
        address callbackAddress,
        bytes4 callbackSelector,
        bytes calldata payload
    ) external payable returns (uint256 requestId) {
        requestId = nextRequestId++;
        emit RequestCreated(requestId, agentId, callbackAddress, callbackSelector, payload, msg.value);
    }

    function getRequestDeposit() external view returns (uint256) {
        return requestDeposit;
    }

    function setRequestDeposit(uint256 newRequestDeposit) external {
        requestDeposit = newRequestDeposit;
    }
}
