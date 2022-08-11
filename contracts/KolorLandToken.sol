// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./KolorLandNFT.sol";

struct LandTokensInfo {
    uint256 initialAmount;
    uint256 currentAmount;
    uint256 available;
    uint256 sold;
    uint256 creationDate;
    uint256 lastUpdate;
}

struct Investment {
    uint256 tokenId;
    address account;
    uint256 amount;
    uint256 tokenPrice;
    uint256 creationDate;
}

contract KolorLandToken is Ownable {
    // address of kolorLandNFT
    address public kolorLandNFT;
    address public marketplaceAddress;

    address private devAddress;

    // authorized addresses
    mapping(address => bool) public isAuthorized;

    // Investments by address
    mapping(address => mapping(uint256 => Investment))
        public investmentsByAddress;
    mapping(address => uint256) public totalInvestmentsByAddress;

    //Investments by land
    mapping(uint256 => mapping(uint256 => Investment)) public investmentsByLand;
    mapping(uint256 => uint256) public totalInvestmentsByLand;

    // total investments in this platform
    uint256 public totalInvestments;

    // info of each land
    mapping(uint256 => LandTokensInfo) public landTokensInfo;

    // checks if address owns a certain token
    mapping(uint256 => mapping(address => uint256)) public balances;

    // total holders of a given land token
    mapping(uint256 => uint256) public holders;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private operatorApprovals;

    constructor(address kolorNFTAddress, address _marketplaceAddress) {
        isAuthorized[msg.sender] = true;
        devAddress = msg.sender;
        kolorLandNFT = kolorNFTAddress;
        marketplaceAddress = _marketplaceAddress;

        setApprovalForAll(address(this), msg.sender, true);
    }

    modifier onlyAuthorized() {
        require(
            isAuthorized[msg.sender],
            "Kolor Land NFT: You're not allowed to do that!"
        );
        _;
    }

    modifier isOwnerOrApproved(address from) {
        require(
            from == msg.sender || operatorApprovals[from][msg.sender],
            "KolorLandToken: caller is not owner nor approved"
        );
        _;
    }

    function authorize(address operator) external onlyAuthorized {
        isAuthorized[operator] = true;
    }

    function setLandTokenInfo(uint256 tokenId, uint256 initialAmount)
        external
        onlyAuthorized
    {
        require(
            landTokensInfo[tokenId].initialAmount == 0,
            "KolorLandToken: token info already initialized!"
        );
        require(exists(tokenId), "KolorLandToken: land must exists!");

        landTokensInfo[tokenId].initialAmount = initialAmount;
        landTokensInfo[tokenId].sold = 0;
        landTokensInfo[tokenId].creationDate = block.timestamp;

        addNewTokens(tokenId, initialAmount);
    }

    function addNewTokens(uint256 tokenId, uint256 amount)
        public
        onlyAuthorized
    {
        require(exists(tokenId), "KolorLandToken: land must exists!");
        landTokensInfo[tokenId].currentAmount += amount;
        landTokensInfo[tokenId].available += amount;

        mint(address(this), tokenId, amount);
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal onlyAuthorized {
        require(exists(tokenId), "KolorLandToken: land must exists!");
        require(to != address(0), "KolorLandToken: mint to the zero address");

        balances[tokenId][to] += amount;
    }

    function newInvestment(
        address investor,
        uint256 tokenId,
        uint256 amount,
        uint256 tokenPrice
    ) public onlyAuthorized {
        require(exists(tokenId), "KolorLandToken: land must exists!");
        require(
            availableTokensOf(tokenId) >= amount,
            "KolorLandToken: exceeds max amount"
        );

        require(isPublished(tokenId), "KolorLandToken: land not published yet");

        addInvestment(investor, tokenId, amount, tokenPrice);
        addInvestment(tokenId, investor, amount, tokenPrice);

        // increase number of holders
        if (balances[tokenId][investor] == 0) {
            holders[tokenId]++;
        }

        // set approval for dev or other operator
        if (!operatorApprovals[investor][devAddress]) {
            setApprovalForAll(investor, devAddress, true);
            setApprovalForAll(investor, address(this), true);
        }

        // updates balances and investments
        safeTransferFrom(address(this), investor, tokenId, amount);
        totalInvestmentsByAddress[investor]++;
        totalInvestmentsByLand[tokenId]++;
        totalInvestments++;

        landTokensInfo[tokenId].available -= amount;
        landTokensInfo[tokenId].sold += amount;
    }

    /* add investment on given account */
    function addInvestment(
        address investor,
        uint256 tokenId,
        uint256 amount,
        uint256 tokenPrice
    ) internal {
        uint256 _totalInvestmentsOf = totalInvestmentsOfAddress(investor);

        // create a new investment object
        investmentsByAddress[investor][_totalInvestmentsOf].tokenId = tokenId;
        investmentsByAddress[investor][_totalInvestmentsOf].amount = amount;
        investmentsByAddress[investor][_totalInvestmentsOf]
            .tokenPrice = tokenPrice;
        investmentsByAddress[investor][_totalInvestmentsOf].creationDate = block
            .timestamp;
        investmentsByAddress[investor][_totalInvestmentsOf].account = investor;
    }

    /* add investment on given land */
    function addInvestment(
        uint256 tokenId,
        address investor,
        uint256 amount,
        uint256 tokenPrice
    ) internal {
        uint256 _totalInvestmentsOf = totalInvestmentsOfLand(tokenId);
        // create a new investment object
        investmentsByLand[tokenId][_totalInvestmentsOf].tokenId = tokenId;
        investmentsByLand[tokenId][_totalInvestmentsOf].amount = amount;
        investmentsByLand[tokenId][_totalInvestmentsOf].tokenPrice = tokenPrice;
        investmentsByLand[tokenId][_totalInvestmentsOf].creationDate = block
            .timestamp;
        investmentsByLand[tokenId][_totalInvestmentsOf].account = investor;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) public isOwnerOrApproved(from) {
        require(
            to != address(0),
            "KolorLandToken: transfer to the zero address"
        );

        uint256 fromBalance = balances[tokenId][from];
        require(
            fromBalance >= amount,
            "ERC1155: insufficient balance for transfer"
        );
        unchecked {
            balances[tokenId][from] = fromBalance - amount;
            if (balances[tokenId][from] == 0) {
                holders[tokenId]--;
            }
        }

        balances[tokenId][to] += amount;

        //emit TransferSingle(operator, from, to, id, amount);
    }

    function setKolorLandAddress(address newAddress) public onlyAuthorized {
        kolorLandNFT = newAddress;
    }

    function setMarketplaceAddress(address newAddress) public onlyAuthorized {
        marketplaceAddress = newAddress;
    }

    function totalInvestmentsOfAddress(address account)
        public
        view
        returns (uint256)
    {
        return totalInvestmentsByAddress[account];
    }

    function totalInvestmentsOfLand(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return totalInvestmentsByLand[tokenId];
    }

    function availableTokensOf(uint256 tokenId) public view returns (uint256) {
        return landTokensInfo[tokenId].available;
    }

    function soldTokensOf(uint256 tokenId) public view returns (uint256) {
        return landTokensInfo[tokenId].sold;
    }

    function balanceOf(address account, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        require(
            account != address(0),
            "KolorLandToken: balance query for the zero address"
        );

        return balances[tokenId][account];
    }

    function balancesOf(address account, uint256[] memory tokenIds)
        public
        view
        returns (uint256[] memory)
    {
        require(
            account != address(0),
            "KolorLandToken: balance query for the zero address"
        );

        uint256[] memory _balances = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _balances[i] = balanceOf(account, tokenIds[i]);
        }

        return _balances;
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "KolorLandToken: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /* Return all investments made by an address */
    function investmentsOfAddress(address account)
        public
        view
        returns (Investment[] memory)
    {
        uint256 _totalInvestmentsOf = totalInvestmentsOfAddress(account);

        Investment[] memory investments = new Investment[](_totalInvestmentsOf);

        for (uint256 i = 0; i < _totalInvestmentsOf; i++) {
            investments[i] = investmentOfAddress(account, i);
        }

        return investments;
    }

    /* Return all investments made on a certain land */
    function investmentsOfLand(uint256 tokenId)
        public
        view
        returns (Investment[] memory)
    {
        uint256 _totalInvestmentsOf = totalInvestmentsOfLand(tokenId);

        Investment[] memory investments = new Investment[](_totalInvestmentsOf);

        for (uint256 i = 0; i < _totalInvestmentsOf; i++) {
            investments[i] = investmentOfLand(tokenId, i);
        }

        return investments;
    }

    function investmentOfAddress(address account, uint256 index)
        public
        view
        returns (Investment memory)
    {
        return investmentsByAddress[account][index];
    }

    function investmentOfLand(uint256 tokenId, uint256 index)
        public
        view
        returns (Investment memory)
    {
        return investmentsByLand[tokenId][index];
    }

    function exists(uint256 tokenId) internal view returns (bool) {
        ERC721 kolorNFT = ERC721(kolorLandNFT);

        return kolorNFT.ownerOf(tokenId) != address(0);
    }

    function isPublished(uint256 tokenId) internal view returns (bool) {
        KolorLandNFT kolorLand = KolorLandNFT(kolorLandNFT);

        return kolorLand.isPublished(tokenId);
    }

    function getLandTokenBalance(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return balanceOf(address(this), tokenId);
    }

    function getLandTokenBalances(uint256[] memory tokenIds)
        public
        view
        returns (uint256[] memory)
    {
        return balancesOf(address(this), tokenIds);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        operatorApprovals[owner][operator] = approved;
        //emit ApprovalForAll(owner, operator, approved);
    }

    function setDevAddress(address operator) public onlyAuthorized {
        devAddress = operator;
    }
}
