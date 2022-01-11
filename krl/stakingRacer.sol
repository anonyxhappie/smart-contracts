// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";


contract RacersNFTStaking is PausableUpgradeable, AccessControlUpgradeable, ERC721HolderUpgradeable {    
    IERC721 public RACE;
    IERC20 public EOC;
    uint256 private rewardRate = 9737802706552708;

    bytes32 public constant CEO = keccak256("CEO");
    bytes32 public constant CTO = keccak256("CTO");
    bytes32 public constant CFO = keccak256("CFO");
    address internal _safe = 0xd8806d66E24b702e0A56fb972b75D24CAd656821;

    /// @notice total Racers staked currently in the gensesis staking contract
    uint256 public stakedRacersTotal;

    uint256 public eocValue;
    uint256 public secsInYear = 365 * 86400;
    uint256 public rewardsPerSec;

    /**
    @notice Struct to track what user is staking which tokens
    @dev tokenIds are all the tokens staked by the staker
    @dev balance is the current MATIC balance of the staker
    @dev rewardsEarned is the total reward for the staker till now
    @dev rewardsReleased is how much reward has been paid to the staker
    */
    struct Staker {
        uint256[] tokenIds;
        mapping (uint256 => uint256) tokenIndex;
        uint256 balance;
        uint256 lastRewardPoints;
        uint256 rewardsReleased;
    }

    /// @notice sets the token to be claimable or not, cannot claim if it set to false
    bool public tokensClaimable;

    /// @notice mapping of a staker to its current properties
    mapping (address => Staker) public stakers;

    // Mapping from token ID to owner address
    mapping (uint256 => address) public tokenOwner;

    // Mapping from token ID to token staked time
    mapping (uint256 => uint256) public tokenStakedTime;

    /// @notice event emitted when a user has staked a token
    event Staked(address owner, uint256 token);

    /// @notice event emitted when a user has unstaked a token
    event Unstaked(address owner, uint256 token);

    /// @notice event emitted when a user claims reward
    event RewardPaid(address indexed user, uint256 reward);
    
    /// @notice Allows reward tokens to be claimed
    event ClaimableStatusUpdated(bool status);


    function initialize(address _RACE, address _EOC) public initializer {
        RACE = IERC721(_RACE);
        EOC = IERC20(_EOC);

        _setupRole(DEFAULT_ADMIN_ROLE, _safe);
        _setupRole(CEO, address(0x47c06B50C2a6D28Ce3B130384b19a8929f414030));
        _setupRole(CFO, _safe);
        _setupRole(CTO, msg.sender);

        tokensClaimable = true;
        eocValue = 13200000000000;
        rewardsPerSec = ((eocValue * 60)/(10**18)) / (365 * 86400);
    }

    modifier validate() {
        require(
            hasRole(CEO, msg.sender) ||
                hasRole(CFO, msg.sender) ||
                hasRole(CTO, msg.sender),
            "SR: Address does not have valid Rights"
        );
        _;
    }
    
    modifier onlyOwner(uint _tokenId) {
        require(
            RACE.ownerOf(_tokenId) == msg.sender,
            "SR: Address does not have valid Rights");
        _;
    }

    /// @notice Lets admin set the Rewards to be claimable
    function setTokensClaimable(bool _enabled) external validate {
        tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }
    
    /// @notice Lets admin set the EOC Token Value
    function setEOCTokenValue(uint256 _eocValue) external validate {
        eocValue = _eocValue;
    }

    /// @dev Getter functions for Staking contract
    /// @dev Get the tokens staked by a user
    function getStakedTokens(address _user) external view returns (uint256[] memory tokenIds) {
        return stakers[_user].tokenIds;
    }

    /**
     * @dev All the staking goes through this function
     * @dev Balance of stakers are updated as they stake the nfts
    */
    function stake(address _user, uint256 _tokenId) public onlyOwner(_tokenId) {
        Staker storage staker = stakers[_user];
        staker.tokenIds.push(_tokenId);
        staker.tokenIndex[staker.tokenIds.length - 1];
        staker.balance += 1;
        tokenOwner[_tokenId] = _user;
        stakedRacersTotal += 1;
        RACE.safeTransferFrom(_user, address(this),  _tokenId);

        tokenStakedTime[_tokenId] = block.timestamp;
        emit Staked(_user, _tokenId);
    }

    /// @notice Stake multiple RACE NFTs and earn reward tokens. 
    function stakeBatch(uint256[] memory tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++) {
            stake(msg.sender, tokenIds[i]);
        }
    }

    /// @notice Lets a user with rewards owing to claim tokens
    function claimReward(address _user, uint256 _tokenId) internal {
        require(tokensClaimable == true, "SR:Tokens cannnot be claimed yet");
        
        Staker storage staker = stakers[_user];
        uint256 payableAmount = (block.timestamp - tokenStakedTime[_tokenId]) * rewardsPerSec;
        require(EOC.balanceOf(address(this)) >= payableAmount * 10 **18, "SR:Tokens cannnot be claimed");
        
        staker.lastRewardPoints = payableAmount;
        staker.rewardsReleased += payableAmount; 
        EOC.transfer(_user, payableAmount);
        emit RewardPaid(_user, payableAmount);
    }

    /**
     * @dev All the unstaking goes through this function
     * @dev Rewards to be given out is calculated
     * @dev Balance of stakers are updated as they unstake the nfts based on ether price
    */
    function unstake(address _user, uint256 _tokenId) public {
        require(tokenOwner[_tokenId] == msg.sender, "SR: Not authorized.");
        Staker storage staker = stakers[_user];

        uint256 lastIndex = staker.tokenIds.length - 1;
        uint256 lastIndexKey = staker.tokenIds[lastIndex];
        uint256 tokenIdIndex = staker.tokenIndex[_tokenId];
        
        staker.balance -= 1;
        staker.tokenIds[tokenIdIndex] = lastIndexKey;
        staker.tokenIndex[lastIndexKey] = tokenIdIndex;
        if (staker.tokenIds.length > 0) {
            staker.tokenIds.pop();
            delete staker.tokenIndex[_tokenId];
        }

        if (staker.balance == 0) {
            delete stakers[_user];
        }
        delete tokenOwner[_tokenId];

        RACE.safeTransferFrom(address(this), _user, _tokenId);
        delete tokenStakedTime[_tokenId];
        claimReward(msg.sender, _tokenId);
        emit Unstaked(_user, _tokenId);
    }

    /// @notice Stake multiple RACE NFTs and claim reward tokens. 
    function unstakeBatch(uint256[] memory tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++) {
            if (tokenOwner[tokenIds[i]] == msg.sender) {
                unstake(msg.sender, tokenIds[i]);
            }
        }
    }

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

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function mint(address recipient, uint amount) external;
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