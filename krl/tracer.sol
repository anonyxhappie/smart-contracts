// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TRacers is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable, UUPSUpgradeable {

    bytes32 public constant CEO = keccak256("CEO");
    bytes32 public constant CTO = keccak256("CTO");
    bytes32 public constant CFO = keccak256("CFO");

    address internal constant _safe = 0xd8806d66E24b702e0A56fb972b75D24CAd656821;

    mapping(uint256 => address) public operatorOf; 
    mapping(uint256 => address) public ownerOfRace; 

    event RacerDepositEvent(address depositor, uint tokenId, uint timestamp);

    function initialize() initializer public {
        __ERC721_init("TRacers", "TRACE");
        __ERC721URIStorage_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _safe);
        _setupRole(CEO, address(0x47c06B50C2a6D28Ce3B130384b19a8929f414030));
        _setupRole(CFO, _safe);
        // _setupRole(CTO, msg.sender);
        _setupRole(CTO, address(0x5a1a41d613676780f6E9684F1C9Fb89e116013f2));
    }

    modifier validate() {
        require(
            hasRole(CEO, msg.sender) ||
                hasRole(CFO, msg.sender) ||
                hasRole(CTO, msg.sender),
            "AccessControl: Address does not have valid Rights"
        );
        _;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "kartracingleague.com/items/";
    }

    function pause() public validate {
        _pause();
    }

    function unpause() public validate {
        _unpause();
    }

    function safeMint(address to, uint256 tokenId) public validate {
        _safeMint(to, tokenId);
        operatorOf[tokenId] = to;
    }

    function safeBurn(uint256 tokenId) public validate {
        _burn(tokenId);
        delete operatorOf[tokenId];
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        validate
        override
    {}

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setOperator(uint256 tokenId, address _operator) external {
        require(ownerOf(tokenId) == msg.sender, "Only Owner can change the operators for TRacers");
        operatorOf[tokenId] = _operator;
    }
}
