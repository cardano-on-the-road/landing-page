pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract KarmaContractFactory{

    address contractOwner;

    mapping(address => address[]) public karmaContractDetailsMapper;

    constructor() payable{
        contractOwner = msg.sender;
    }

    function createKarmaContract(string memory name, string memory symbol,
        uint96 productprice, uint256 setupMintingLimit, uint96 tokenMaxUsage,
        uint96 campaignRoyaltiesPerc, uint96 campaignCashbackPerc) public payable{
            address karmaContractAddress = address(new KarmaContract(contractOwner, name, symbol, productprice, setupMintingLimit, tokenMaxUsage, campaignRoyaltiesPerc, campaignCashbackPerc));
            address[] storage KarmaContractDetailsCollection = karmaContractDetailsMapper[contractOwner];
            KarmaContractDetailsCollection.push(karmaContractAddress);
    }

    function getDeployedKarmaContractForAddress() public view returns (address[] memory ){
        return karmaContractDetailsMapper[msg.sender];
    }
}

contract KarmaContract is ERC721URIStorage, AccessControl  {
    
    using Counters for Counters.Counter;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VISIBILITY_PROVIDER_ROLE = keccak256("VISIBILITY_PROVIDER_ROLE");
    address payable public admin;
    Counters.Counter private _tokenIds;
    string public productName;
    uint public productPrice;
    uint96 public royaltiesPerc;
    uint96 public cashbackPerc;
    uint96 public tokenMaxUsages;

    struct TokenInstance {
        uint256 maxUsages;
        uint256 usageCounter;
    }

    struct SellTokenFlags {
        uint256 price;
        bool payed;
        bool approved;
    }

    mapping(uint256 => address payable) public royaltiesAddressMapper;
    mapping(uint256 => TokenInstance) public tokenInstanceMapper;
    
    uint256 public mintingLimit;

    constructor(address owner, string memory nftName, string memory symbol,
        uint256 productprice, uint256 setupMintingLimit, uint96 tokenMaxUsage,
        uint96 campaignRoyaltiesPerc, uint96 campaignCashbackPerc) 
            ERC721(nftName, symbol) payable {
                _setupRole(ADMIN_ROLE, owner);
                _setupRole(MINTER_ROLE, owner);
                
                productPrice = productprice;
                tokenMaxUsages= tokenMaxUsage;
                royaltiesPerc = campaignRoyaltiesPerc;
                cashbackPerc = campaignCashbackPerc;

                admin = payable(owner);
                mintingLimit = setupMintingLimit;
    }

    function mintItem(address player, string memory uri) 
        public returns (uint256){
            //Need a different permission to mint token
            require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a MINTER");
            require(mintingLimit > _tokenIds.current() + 1, 'Minted items limit reached');
            uint256 newItemId = _tokenIds.current();

            tokenInstanceMapper[newItemId] = TokenInstance({
                maxUsages: tokenMaxUsages,
                usageCounter: 0
            });

            
            _mint(player, newItemId);
            _setTokenURI(newItemId, uri);
            royaltiesAddressMapper[newItemId] = payable(player);
            _tokenIds.increment();
            return newItemId;
    }

    function cashOut() public payable{
        require(hasRole(ADMIN_ROLE, msg.sender), "Only ADMIN can do cashout");
        admin.transfer(address(this).balance);
    }

    function pay() public payable{

    }

    function payWithNft(uint256 tokenId) public payable{
        require(msg.value >= productPrice, "not enought money sent");
        require(ownerOf(tokenId) == msg.sender, "You're not the owner of the Item");
        TokenInstance storage ti = tokenInstanceMapper[tokenId]; 
        require(ti.usageCounter < ti.maxUsages, "The nft is not valid anymore. Maxusages reached");
        //handle the cashback
        ti.usageCounter = ti.usageCounter + 1; 

        uint256 cashback = msg.value * cashbackPerc / 100;
        uint256 royalties = msg.value * royaltiesPerc / 100;

        royaltiesAddressMapper[tokenId].transfer(royalties);
        address payable cashbackAddress = payable(msg.sender);
        cashbackAddress.transfer(cashback);

    }

    function transfer(address recipient, uint256 tokenId) public payable returns (bool) {
        _transfer(_msgSender(), recipient, tokenId);
      return true;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}