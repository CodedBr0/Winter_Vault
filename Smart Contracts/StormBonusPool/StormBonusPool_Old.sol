// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);
    bool private _paused;

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

abstract contract Ownable is Context {
    address private _owner;
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract StormBonusPool is Ownable, Pausable, ReentrancyGuard {
    IERC20 public lpToken;
    IERC20 public rewardToken;
    uint256 public monthlyRewardPercentage;

    struct Staker {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 lastStakedTime;
    }

    mapping(address => Staker) public stakers;

    // Constructor
    constructor(address _lpToken, address _rewardToken, uint256 _monthlyRewardPercentage, address _initialOwner)
        Ownable(_initialOwner) {
        lpToken = IERC20(_lpToken);
        rewardToken = IERC20(_rewardToken);
        monthlyRewardPercentage = _monthlyRewardPercentage;
    }

    // Owner's functions
    function depositRewardToken(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function renounceOwnership() public override onlyOwner {
        super.renounceOwnership();
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateMonthlyRewardPercentage(uint256 _newPercentage) external onlyOwner {
        monthlyRewardPercentage = _newPercentage;
    }

    function withdrawAllRewardToken() external onlyOwner {
        uint256 balance = rewardToken.balanceOf(address(this));
        rewardToken.transfer(msg.sender, balance);
    }

    function withdrawStuckERC20(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    // Users' functions
    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        lpToken.transferFrom(msg.sender, address(this), _amount);
        
        Staker storage staker = stakers[msg.sender];
        _updateReward(msg.sender);

        staker.stakedAmount += _amount;
        staker.lastStakedTime = block.timestamp; // Reset lastStakedTime on each stake
    }

    function unstake(uint256 _amount) external whenNotPaused nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount >= _amount, "Insufficient staked amount");

        _updateReward(msg.sender);

        // Withdraw pending rewards
        uint256 pendingReward = staker.rewardDebt;
        if (pendingReward > 0) {
            staker.rewardDebt = 0;
            rewardToken.transfer(msg.sender, pendingReward);
        }
        
        staker.stakedAmount -= _amount;
        lpToken.transfer(msg.sender, _amount);
        
        staker.lastStakedTime = block.timestamp; // Reset lastStaked Time even when partially unstaking
        if (staker.stakedAmount == 0) {
            staker.lastStakedTime = 0; // Optionally, reset to 0 if all tokens are unstaked
        }
    }

    function autoCompound() external whenNotPaused nonReentrant {
        Staker storage staker = stakers[msg.sender];
        _updateReward(msg.sender);

        uint256 reward = staker.rewardDebt;
        if (reward > 0) {
            staker.rewardDebt = 0;
            staker.stakedAmount += reward; // Compounding the reward to the staked amount
        }
        staker.lastStakedTime = block.timestamp; // Reset lastStakedTime on auto-compounding
    }

    function _updateReward(address _staker) internal {
        Staker storage staker = stakers[_staker];
        uint256 stakedDuration = block.timestamp - staker.lastStakedTime;
        if (stakedDuration > 0 && staker.stakedAmount > 0) {
            uint256 reward = (staker.stakedAmount * monthlyRewardPercentage * stakedDuration / 30 days) / 1000;
            staker.rewardDebt += reward;
        }
    }

    // View functions
    function APY() external view returns (uint256) {
        return monthlyRewardPercentage * 12 / 10;
    }

    function getMonthlyRewardPercentage() external view returns (uint256) {
        return monthlyRewardPercentage;
    }

    function checkOtherERC20Tokens(address _tokenAddress) external view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress);
        return token.balanceOf(address(this));
    }

    function getUserView(address _user) external view returns (uint256 stakedAmount, uint256 pendingReward) {
        Staker storage staker = stakers[_user];
        uint256 stakedDuration = block.timestamp - staker.lastStakedTime;
        uint256 reward = (staker.stakedAmount * monthlyRewardPercentage * stakedDuration / 30 days) / 1000;
        return (staker.stakedAmount, staker.rewardDebt + reward);
    }

    function totalStaked() external view returns (uint256) {
        return lpToken.balanceOf(address(this));
    }

    function contractRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function ownerAddress() external view returns (address) {
        return owner();
    }
}
