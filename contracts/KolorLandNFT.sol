// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IKolorLandNFT.sol";

struct GeoSpatialPoint {
    int256 latitude;
    int256 longitude;
    uint256 decimals;
    uint256 creationDate;
    uint256 updateDate;
}

struct Species {
    string speciesAlias;
    string scientificName;
    uint256 density;
    uint256 size;
    uint256 decimals;
    uint256 TCO2perSecond;
    uint256 TCO2perYear;
    uint256 landId;
    uint256 creationDate;
    uint256 updateDate;
}

struct NFTInfo {
    string name;
    string identifier;
    address landOwner;
    string landOwnerAlias;
    uint256 decimals;
    uint256 size;
    string country;
    string stateOrRegion;
    string city;
    State state;
    uint256 initialTCO2perYear;
    uint256 soldTCO2;
    uint256 creationDate;
}

contract KolorLandNFT is
    ERC721,
    ERC721Enumerable,
    ERC721Burnable,
    Ownable,
    IKolorLandNFT
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    address public marketplace;

    constructor() ERC721("Kolor Land NFT", "KLand") {
        isAuthorized[msg.sender] = true;
    }

    string public baseURI;

    // NFT info
    mapping(uint256 => NFTInfo) private mintedNFTSInfo;

    // Owned lands to use in enumeration
    mapping(address => mapping(uint256 => uint256)) private ownedLands;
    mapping(uint256 => uint256) private landIndex;
    mapping(address => uint256) private _totalLandOwned;

    // mapping to get buyers of a land
    mapping(uint256 => mapping(address => bool)) public buyers;
    mapping(uint256 => uint256) public totalBuyers;

    // mappings of conflictive data such as species and location
    mapping(uint256 => mapping(uint256 => Species)) public species;
    mapping(uint256 => uint256) public totalSpecies;

    mapping(uint256 => mapping(uint256 => GeoSpatialPoint)) public points;
    mapping(uint256 => uint256) public totalPoints;

    mapping(address => bool) public isAuthorized; //hot wallet, owner is cold wallet

    function safeMint(
        address to,
        string memory name,
        string memory identifier,
        address landOwner,
        string memory landOwnerAlias,
        uint256 decimals,
        uint256 size,
        string memory country,
        string memory stateOrRegion,
        string memory city,
        uint256 initialTCO2
    ) public onlyAuthorized {
        uint256 currentTokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, currentTokenId);

        // Set all NFT information
        mintedNFTSInfo[currentTokenId].name = name;
        mintedNFTSInfo[currentTokenId].identifier = identifier;
        mintedNFTSInfo[currentTokenId].landOwner = landOwner;
        mintedNFTSInfo[currentTokenId].landOwnerAlias = landOwnerAlias;
        mintedNFTSInfo[currentTokenId].decimals = decimals;
        mintedNFTSInfo[currentTokenId].size = size;
        mintedNFTSInfo[currentTokenId].country = country;
        mintedNFTSInfo[currentTokenId].stateOrRegion = stateOrRegion;
        mintedNFTSInfo[currentTokenId].city = city;
        mintedNFTSInfo[currentTokenId].initialTCO2perYear = initialTCO2;
        mintedNFTSInfo[currentTokenId].creationDate = block.timestamp;
        mintedNFTSInfo[currentTokenId].state = State.Created;

        uint256 _landsOwned = _totalLandOwned[landOwner];
        // set the tokenId to current landowner collection index
        ownedLands[landOwner][_landsOwned] = currentTokenId;

        // update the tokenId index in landowner collection
        landIndex[currentTokenId] = _landsOwned;

        // increase total lands owned by address
        _totalLandOwned[landOwner]++;
    }

    function authorize(address manager) public onlyOwner {
        isAuthorized[manager] = !isAuthorized[manager];
    }

    function setMarketplace(address _marketplace) public onlyAuthorized {
        marketplace = _marketplace;
        isAuthorized[marketplace] = true;
    }

    modifier onlyMarketplace() {
        require(
            marketplace == msg.sender,
            "Kolor Land NFT: You're not allowed to do that!"
        );
        _;
    }

    modifier onlyAuthorized() {
        require(
            isAuthorized[msg.sender],
            "Kolor Land NFT: You're not allowed to do that!"
        );
        _;
    }

    modifier notBurned(uint256 tokenId) {
        require(_exists(tokenId), "ERC721Metadata: operation on burned token!");
        _;
    }

    modifier notPublishedNorRemoved(uint256 tokenId) {
        require(
            !isRemoved(tokenId) && !isPublished(tokenId),
            "Kolor Land NFT:  This land can't be transfered to Marketplace"
        );
        _;
    }

    function isLandOwner(address landOwner, uint256 tokenId)
        public
        view
        returns (bool)
    {
        return mintedNFTSInfo[tokenId].landOwner == landOwner;
    }

    function isRemoved(uint256 tokenId) public view returns (bool) {
        return mintedNFTSInfo[tokenId].state == State.Removed;
    }

    function isPublished(uint256 tokenId) public view returns (bool) {
        return mintedNFTSInfo[tokenId].state == State.Published;
    }

    /**
        @dev Override of functions defined on interface ILandNFT
    
     */
    function updateLandState(uint256 tokenId, State _state)
        public
        override
        notBurned(tokenId)
        onlyAuthorized
    {
        require(_state != State.Created, "Kolor Land NFT: Invalid State");
        mintedNFTSInfo[tokenId].state = _state;
    }

    /**  
        @dev adds a new buyer to this land 
    */
    function addBuyer(uint256 tokenId, address newBuyer)
        public
        override
        onlyMarketplace
        notBurned(tokenId)
    {
        if (!buyers[tokenId][newBuyer]) {
            buyers[tokenId][newBuyer] = true;
            totalBuyers[tokenId]++;
        }
    }

    function updateName(uint256 tokenId, string memory newName)
        public
        override
        onlyAuthorized
        notBurned(tokenId)
    {
        mintedNFTSInfo[tokenId].name = newName;
    }

    function landOwnerOf(uint256 tokenId)
        public
        view
        override
        returns (address)
    {
        address landOwner = mintedNFTSInfo[tokenId].landOwner;

        return landOwner;
    }

    function landIndexOf(uint256 tokenId) public view returns (uint256) {
        return landIndex[tokenId];
    }

    function isBuyerOf(uint256 tokenId, address buyer)
        public
        view
        override
        returns (bool)
    {
        return buyers[tokenId][buyer];
    }

    function initialTCO2Of(uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        return mintedNFTSInfo[tokenId].initialTCO2perYear;
    }

    function stateOf(uint256 tokenId) public view override returns (State) {
        return mintedNFTSInfo[tokenId].state;
    }

    /**
        @dev transfers the token to the marketplace and marks it
        as published for buyers to invest

     */
    function safeTransferToMarketplace(address from, uint256 tokenId)
        public
        override
        notBurned(tokenId)
        onlyAuthorized
        notPublishedNorRemoved(tokenId)
    {
        // Transfer to the marketplace
        updateLandState(tokenId, State.Published);
        safeTransferFrom(from, marketplace, tokenId);
    }

    function getNFTInfo(uint256 tokenId) public view returns (NFTInfo memory) {
        return mintedNFTSInfo[tokenId];
    }

    function landOfOwnerByIndex(address landOwner, uint256 index)
        public
        view
        returns (uint256)
    {
        require(
            index < totalLandOwnedOf(landOwner), // TODO: REPLACE FOR TOTALLANDOWNED OF
            "landowner index out of bounds"
        );

        return ownedLands[landOwner][index];
    }

    function totalLandOwnedOf(address landOwner) public view returns (uint256) {
        return _totalLandOwned[landOwner];
    }

    function totalSpeciesOf(uint256 tokenId) public view returns (uint256) {
        return totalSpecies[tokenId];
    }

    function totalPointsOf(uint256 tokenId) public view returns (uint256) {
        return totalPoints[tokenId];
    }

    /** @dev set all species of a certain land */
    function setSpecies(uint256 tokenId, Species[] memory _species)
        public
        onlyAuthorized
        notBurned(tokenId)
    {
        require(
            totalSpeciesOf(tokenId) == 0,
            "Kolor Land NFT: Species of this land already been set"
        );
        uint256 _totalSpecies = _species.length;
        for (uint256 i = 0; i < _totalSpecies; i++) {
            species[tokenId][i].speciesAlias = _species[i].speciesAlias;
            species[tokenId][i].scientificName = _species[i].scientificName;
            species[tokenId][i].density = _species[i].density;
            species[tokenId][i].size = _species[i].size;
            species[tokenId][i].decimals = _species[i].decimals;
            species[tokenId][i].TCO2perSecond = _species[i].TCO2perSecond;
            species[tokenId][i].TCO2perYear = _species[i].TCO2perYear;
            species[tokenId][i].landId = tokenId;
            species[tokenId][i].creationDate = block.timestamp;
        }

        totalSpecies[tokenId] = _totalSpecies;
    }

    function addSpecies(uint256 tokenId, Species memory _species)
        public
        onlyAuthorized
        notBurned(tokenId)
    {
        uint256 _totalSpecies = totalSpeciesOf(tokenId);
        species[tokenId][_totalSpecies].speciesAlias = _species.speciesAlias;
        species[tokenId][_totalSpecies].scientificName = _species
            .scientificName;
        species[tokenId][_totalSpecies].density = _species.density;
        species[tokenId][_totalSpecies].size = _species.size;
        species[tokenId][_totalSpecies].decimals = _species.decimals;
        species[tokenId][_totalSpecies].TCO2perYear = _species.TCO2perYear;
        species[tokenId][_totalSpecies].landId = tokenId;
        species[tokenId][_totalSpecies].creationDate = block.timestamp;
        species[tokenId][_totalSpecies].TCO2perSecond = _species.TCO2perSecond;

        totalSpecies[tokenId]++;
    }

    function updateSpecies(
        uint256 tokenId,
        uint256 speciesIndex,
        Species memory _species
    ) public onlyAuthorized notBurned(tokenId) {
        require(
            validSpecie(speciesIndex, tokenId),
            "Kolor Land NFT: Invalid specie to update"
        );

        species[tokenId][speciesIndex].speciesAlias = _species.speciesAlias;
        species[tokenId][speciesIndex].scientificName = _species.scientificName;
        species[tokenId][speciesIndex].density = _species.density;
        species[tokenId][speciesIndex].size = _species.size;
        species[tokenId][speciesIndex].TCO2perYear = _species.TCO2perYear;
        species[tokenId][speciesIndex].landId = tokenId;
        species[tokenId][speciesIndex].updateDate = block.timestamp;
        species[tokenId][speciesIndex].TCO2perSecond = _species.TCO2perSecond;
    }

    function setPoints(uint256 tokenId, GeoSpatialPoint[] memory _points)
        public
        onlyAuthorized
        notBurned(tokenId)
    {
        require(
            totalPointsOf(tokenId) == 0,
            "Kolor Land NFT: Geospatial points of this land already been set"
        );
        uint256 _totalPoints = _points.length;

        for (uint256 i = 0; i < _totalPoints; i++) {
            points[tokenId][i].latitude = _points[i].latitude;
            points[tokenId][i].longitude = _points[i].longitude;
            points[tokenId][i].decimals = _points[i].decimals;
            points[tokenId][i].creationDate = block.timestamp;

            totalPoints[tokenId]++;
        }
    }

    function addPoint(uint256 tokenId, GeoSpatialPoint memory point)
        public
        onlyAuthorized
        notBurned(tokenId)
    {
        uint256 _totalPoints = totalPoints[tokenId];

        points[tokenId][_totalPoints].latitude = point.latitude;
        points[tokenId][_totalPoints].longitude = point.longitude;
        points[tokenId][_totalPoints].decimals = point.decimals;

        totalPoints[tokenId]++;
    }

    function updatePoint(
        uint256 tokenId,
        uint256 pointIndex,
        GeoSpatialPoint memory point
    ) public onlyAuthorized notBurned(tokenId) {
        require(
            validPoint(pointIndex, tokenId),
            "Kolor Land NFT: Invalid point to update"
        );

        points[tokenId][pointIndex].latitude = point.latitude;
        points[tokenId][pointIndex].longitude = point.longitude;
        points[tokenId][pointIndex].decimals = point.decimals;
    }

    function validSpecie(uint256 specieIndex, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        if (specieIndex >= 0 && specieIndex < totalSpeciesOf(tokenId)) {
            return true;
        }

        return false;
    }

    function validPoint(uint256 pointIndex, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        if (pointIndex >= 0 && pointIndex < totalPointsOf(tokenId)) {
            return true;
        }

        return false;
    }

    function offsetEmissions(uint256 tokenId, uint256 amount)
        public
        onlyMarketplace
        notBurned(tokenId)
    {
        mintedNFTSInfo[tokenId].soldTCO2 += amount;
    }

    function totalVCUBySpecies(uint256 tokenId, uint256 index)
        public
        view
        returns (uint256)
    {
        // Get the seconds elapsed until now
        uint256 speciesCreationDate = species[tokenId][index].creationDate;

        uint256 secondsElapsed = timestampDifference(
            speciesCreationDate,
            block.timestamp
        );

        // now we get the total vcus emitted until now
        return secondsElapsed * species[tokenId][index].TCO2perSecond;
    }

    function totalVCUSEmitedBy(uint256 tokenId) public view returns (uint256) {
        // Get total species of a land
        uint256 _totalSpecies = totalSpeciesOf(tokenId);

        uint256 totalVCUSEmitted = 0;
        // Iterate over all species and calculate its total vcu
        for (uint256 i = 0; i < _totalSpecies; i++) {
            uint256 currentVCUSEmitted = totalVCUBySpecies(tokenId, i);
            totalVCUSEmitted += currentVCUSEmitted;
        }

        return totalVCUSEmitted;
    }

    /**
        @dev returns vcus emitted from this land that are available
        for sale
    
     */
    function getVCUSLeft(uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        // Get the ideal vcutokens from creation date until now
        uint256 totalVCUSEmited = totalVCUSEmitedBy(tokenId);

        // get the difference between the ideal minus the sold TCO2
        return totalVCUSEmited - mintedNFTSInfo[tokenId].soldTCO2;
    }

    function timestampDifference(uint256 timestamp1, uint256 timestamp2)
        public
        pure
        returns (uint256)
    {
        return timestamp2 - timestamp1;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return
            string(
                abi.encodePacked(baseURI, mintedNFTSInfo[tokenId].identifier)
            );
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
