// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./KolorLandNFT.sol";

struct OffsetEmission {
    uint256 vcuOffset;
    uint256 offsetDate;
    uint256 vcuPrice;
    uint256 tokenId;
    address account;
}

contract KolorMarketplace is Ownable, ReentrancyGuard, IERC721Receiver {
    // Address of the nft contract and kolor
    address public KolorLandNFTAddress;

    // Mapping from token Id to the timestamp when it was staked
    // in this contract
    mapping(uint256 => uint256) private lockStartTime;

    // mapping from account to its offsets
    mapping(address => mapping(uint256 => OffsetEmission))
        public offsetsByAddress;
    mapping(address => uint256) public totalOffsetsOfAddress;

    // mapping from token id land to its offsets
    mapping(uint256 => mapping(uint256 => OffsetEmission)) public offsetsByLand;
    mapping(uint256 => uint256) public totalOffsetsOfLand;

    mapping(address => bool) public isAuthorized;

    constructor() {
        isAuthorized[msg.sender] = true;
    }

    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender], "You're not allowed to do that");
        _;
    }

    function setNFTAddress(address _NFTAddress) public onlyOwner {
        KolorLandNFTAddress = _NFTAddress;
    }

    /**
        @dev Withdraw a published land from the marketplace

     */
    function removeLand(uint256 tokenId) public onlyAuthorized nonReentrant {
        IKolorLandNFT ilandInterface = IKolorLandNFT(KolorLandNFTAddress);

        // update the land state to paused
        ilandInterface.updateLandState(tokenId, State.Paused);
    }

    /**
        @dev Register a new buying of vcu tokens

     */
    function offsetEmissions(
        uint256 tokenId,
        uint256 emissions,
        uint256 vcuPrice,
        address account
    ) external payable onlyAuthorized nonReentrant {
        IKolorLandNFT ilandInterface = IKolorLandNFT(KolorLandNFTAddress);
        KolorLandNFT kolorLand = KolorLandNFT(KolorLandNFTAddress);
        IERC721 erc721 = IERC721(KolorLandNFTAddress);

        require(
            ilandInterface.stateOf(tokenId) == State.Published,
            "This land NFT is not available!"
        );

        require(
            ilandInterface.getVCUSLeft(tokenId) >= emissions,
            "This land hasn't that much TCO2 to offset"
        );

        require(erc721.ownerOf(tokenId) != address(0), "Token doesn't exists!");

        // Add a new account to token Info
        ilandInterface.addBuyer(tokenId, account);

        // Create new information about this offset
        addOffsetEmissions(tokenId, emissions, vcuPrice, account);

        //Add Offset emissions in nft contract info
        kolorLand.offsetEmissions(tokenId, emissions);
    }

    /** @dev Adds a new offset structure to a account to represent
        its newly offset
    */
    function addOffsetEmissions(
        uint256 tokenId,
        uint256 emissions,
        uint256 vcuPrice,
        address account
    ) internal {
        addOffsetsEmissionsOfBuyer(tokenId, emissions, vcuPrice, account);
        addOffsetsEmmisionsOfLand(tokenId, emissions, vcuPrice, account);
    }

    /**
        @dev updates registry of emissions per client 
    
    */
    function addOffsetsEmissionsOfBuyer(
        uint256 tokenId,
        uint256 emissions,
        uint256 vcuPrice,
        address account
    ) public onlyAuthorized {
        uint256 currentOffsetsOf = totalOffsetsOfAddress[account];

        // add offset
        offsetsByAddress[account][currentOffsetsOf].vcuOffset = emissions;
        offsetsByAddress[account][currentOffsetsOf].offsetDate = block
            .timestamp;
        offsetsByAddress[account][currentOffsetsOf].tokenId = tokenId;
        offsetsByAddress[account][currentOffsetsOf].vcuPrice = vcuPrice;
        offsetsByAddress[account][currentOffsetsOf].account = account;

        // get the current offset emissions of this address
        totalOffsetsOfAddress[account]++;
    }

    /**
        @dev updates registry of emissions per land 
    
    */
    function addOffsetsEmmisionsOfLand(
        uint256 tokenId,
        uint256 emissions,
        uint256 vcuPrice,
        address account
    ) public onlyAuthorized {
        uint256 currentOffsetsOf = totalOffsetsOfLand[tokenId];

        // add offset
        offsetsByLand[tokenId][currentOffsetsOf].vcuOffset = emissions;
        offsetsByLand[tokenId][currentOffsetsOf].offsetDate = block.timestamp;
        offsetsByLand[tokenId][currentOffsetsOf].tokenId = tokenId;

        offsetsByLand[tokenId][currentOffsetsOf].vcuPrice = vcuPrice;
        offsetsByLand[tokenId][currentOffsetsOf].account = account;

        // get the current offset emissions of this land
        totalOffsetsOfLand[tokenId]++;
    }

    function totalOffsetsOf(address account) public view returns (uint256) {
        return totalOffsetsOfAddress[account];
    }

    function totalOffsetsOf(uint256 tokenId) public view returns (uint256) {
        return totalOffsetsOfLand[tokenId];
    }

    /**
        @dev returns offsets of given land
    */
    function offsetsOf(uint256 tokenId)
        public
        view
        returns (OffsetEmission[] memory)
    {
        uint256 _totalOffsetsOf = totalOffsetsOf(tokenId);

        OffsetEmission[] memory offsets = new OffsetEmission[](_totalOffsetsOf);

        for (uint256 i = 0; i < _totalOffsetsOf; i++) {
            offsets[i] = offsetInfo(i, tokenId);
        }

        return offsets;
    }

    /**
        @dev returns offsets of given account
    */
    function offsetsOf(address account)
        public
        view
        returns (OffsetEmission[] memory)
    {
        uint256 _totalOffsetsOf = totalOffsetsOf(account);

        OffsetEmission[] memory offsets = new OffsetEmission[](_totalOffsetsOf);

        for (uint256 i = 0; i < _totalOffsetsOf; i++) {
            offsets[i] = offsetInfo(i, account);
        }

        return offsets;
    }

    /**
        @dev returns offset info of given land and offset
        
    */
    function offsetInfo(uint256 offsetId, uint256 tokenId)
        public
        view
        returns (OffsetEmission memory)
    {
        return offsetsByLand[tokenId][offsetId];
    }

    /**
        @dev returns offset info of given account and offset
        
    */
    function offsetInfo(uint256 offsetId, address account)
        public
        view
        returns (OffsetEmission memory)
    {
        return offsetsByAddress[account][offsetId];
    }

    /**
        @dev Returns the amount of CELO in this contract
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function authorize(address manager) public onlyOwner {
        isAuthorized[manager] = !isAuthorized[manager];
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
