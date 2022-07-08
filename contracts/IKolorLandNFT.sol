// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

enum State {
    Created,
    Paused,
    Removed,
    Published
}

interface IKolorLandNFT {
    /**
        @dev Updates the availibility of tokenized land to be
        purchased in a marketplace
    
     */
    function updateLandState(uint256 tokenId, State state) external;

    function updateLandOwner(
        uint256 tokenId,
        address newLandOwner,
        string memory name
    ) external;

    function addBuyer(uint256 tokenId, address newBuyer) external;

    function updateName(uint256 tokenId, string memory name) external;

    function landOwnerOf(uint256 tokenId)
        external
        view
        returns (address landOwner);

    function isBuyerOf(uint256 tokenId, address buyer)
        external
        view
        returns (bool);

    function initialTCO2Of(uint256 tokenId)
        external
        view
        returns (uint256 initialTCO2);

    function stateOf(uint256 tokenId) external view returns (State state);

    function safeTransferToMarketplace(address from, uint256 tokenId) external;

    function getVCUSLeft(uint256 tokenId) external view returns (uint256 vcus);
}
