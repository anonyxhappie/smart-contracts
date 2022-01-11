// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RacerSale is Initializable, AccessControlUpgradeable, PausableUpgradeable  {
    IERC20 public KRL;
    IERC721 public RACE;
    uint256 private tokenRate;
    uint256 private capSize;

    bytes32 public constant CEO = keccak256("CEO");
    bytes32 public constant CTO = keccak256("CTO");
    bytes32 public constant CFO = keccak256("CFO");
    address internal _safe = 0xd8806d66E24b702e0A56fb972b75D24CAd656821;

    uint public NFTSold;

    struct Sale {
        address buyer;
        uint amount;
        uint tokenId;
        uint timestamp;
    }

    mapping(uint => Sale) public sales;

    event NFTSoldEvent(address buyer, uint amount, uint tokenId, uint timestamp);

    function initialize(address _KRL, address _RACE) public initializer {
        KRL = IERC20(_KRL);
        RACE = IERC721(_RACE);

        capSize = 2000;
        tokenRate = 1; // KRL -> 65 * 10 ** 18;
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

    function setTokenRate(uint _tokenRate) public validate {
        tokenRate = _tokenRate;
        // tokenRate = _tokenRate * 10 ** 18;
    }

    function getTokenRate() public view returns (uint256) {
        return tokenRate;
    }

    function setCapSize(uint _capSize) public validate {
        capSize = _capSize;
    }

    function getCapSize() public view returns (uint256) {
        return capSize;
    }

    function saleRacer(uint _tokenId) public {
        require(capSize >= _tokenId, "Token sale limit exceeded");
        require(KRL.balanceOf(msg.sender) >= tokenRate, "Insufficient balance");

        KRL.transferFrom(msg.sender, _safe, tokenRate);
        RACE.safeMint(msg.sender, _tokenId);
        sales[NFTSold++] = Sale(msg.sender, tokenRate, _tokenId, block.timestamp);
        emit NFTSoldEvent(msg.sender, tokenRate, _tokenId, block.timestamp);
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeMint(address to, uint256 tokenId) external;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}