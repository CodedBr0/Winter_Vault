// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    uint256 private _lastPauseTime;

    constructor() {
        _paused = false;
        _lastPauseTime = 0;
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

    function lastPauseTime() public view virtual returns (uint256) {
        return _lastPauseTime;
    }

    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        _lastPauseTime = block.timestamp;
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
        uint256 unpaidRewards;
        uint256 lastPauseTime;
    }

    mapping(address => Staker) public stakers;
    uint256 public totalStakedBalance; // Total staked LP tokens balance
    uint256 public totalRewardTokenBalance; // Total reward tokens balance

    bool private stakingPaused;

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
        bool success = rewardToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        totalRewardTokenBalance += _amount;
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

    function pauseStaking() external onlyOwner {
        stakingPaused = true;
    }

    function unpauseStaking() external onlyOwner {
        stakingPaused = false;
    }

    function updateMonthlyRewardPercentage(uint256 _newPercentage) external onlyOwner {
        monthlyRewardPercentage = _newPercentage;
    }

    function withdrawAllRewardToken() external onlyOwner {
        uint256 balance = rewardToken.balanceOf(address(this));
        bool success = rewardToken.transfer(msg.sender, balance);
        require(success, "Transfer failed");
        totalRewardTokenBalance -= balance;
    }

    function withdrawStuckERC20(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        bool success = token.transfer(msg.sender, balance);
        require(success, "Transfer failed");
        if (_tokenAddress == address(rewardToken)) {
            totalRewardTokenBalance -= balance;
        }
    }

    function withdrawStuckETH() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance in contract");

        (bool success, ) = payable(_msgSender()).call{value: balance, gas: 30000}("");
        require(success, "Transfer failed.");
    }

    // Users' functions
    function stake(uint256 _amount) external nonReentrant whenNotPaused {
        require(!stakingPaused, "Staking is paused");
        require(_amount > 0, "Amount must be greater than 0");
        bool success = lpToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        
        Staker storage staker = stakers[msg.sender];
        _updateReward(msg.sender);

        staker.stakedAmount += _amount;
        staker.lastStakedTime = block.timestamp; // Reset lastStakedTime on each stake
        staker.lastPauseTime = lastPauseTime(); // Update last pause time
        
        totalStakedBalance += _amount; // Update total staked balance
        _checkUserRewardTokenBalance(msg.sender);
    }

    function unstake(uint256 _amount) external nonReentrant whenNotPaused {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount >= _amount, "Insufficient staked amount");

        _updateReward(msg.sender);

        // Withdraw pending rewards
        uint256 pendingReward = staker.rewardDebt;
        staker.rewardDebt = 0; // Reset reward debt to 0 regardless of the reward token transfer success

        if (pendingReward > 0) {
            if (rewardToken.balanceOf(address(this)) >= pendingReward) {
                bool rewardTransferSuccess = rewardToken.transfer(msg.sender, pendingReward);
                require(rewardTransferSuccess, "Reward transfer failed");
                totalRewardTokenBalance -= pendingReward; // Update total reward token balance
            } else {
                // If there are not enough reward tokens, track the unpaid rewards
                staker.unpaidRewards += pendingReward;
                emit InsufficientRewardTokens(msg.sender, pendingReward);
            }
        }
        
        staker.stakedAmount -= _amount;
        bool lpTransferSuccess = lpToken.transfer(msg.sender, _amount);
        require(lpTransferSuccess, "Transfer failed");
        
        staker.lastStakedTime = block.timestamp; // Reset lastStaked Time even when partially unstaking
        staker.lastPauseTime = lastPauseTime(); // Update last pause time
        if (staker.stakedAmount == 0) {
            staker.lastStakedTime = 0; // Optionally, reset to 0 if all tokens are unstaked
        }
        
        totalStakedBalance -= _amount; // Update total staked balance
        _checkUserRewardTokenBalance(msg.sender);
    }

    function autoCompound() external nonReentrant whenNotPaused {
        require(!stakingPaused, "Auto-compounding is paused");
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount > 0, "No staked amount");

        _updateReward(msg.sender);

        uint256 pendingReward = staker.rewardDebt;
        staker.rewardDebt = 0; // Reset reward debt to 0

        if (pendingReward > 0) {
            if (rewardToken.balanceOf(address(this)) >= pendingReward) {
                // Transfer reward tokens to this contract
                bool rewardTransferSuccess = rewardToken.transfer(address(this), pendingReward);
                require(rewardTransferSuccess, "Reward transfer failed");
                staker.stakedAmount += pendingReward; // Compound the rewards into staked amount
                totalStakedBalance += pendingReward; // Update total staked balance
                totalRewardTokenBalance -= pendingReward; // Update total reward token balance
            } else {
                staker.unpaidRewards += pendingReward;
                emit InsufficientRewardTokens(msg.sender, pendingReward);
            }
        }

        staker.lastStakedTime = block.timestamp; // Reset lastStakedTime on each auto-compound
        _checkUserRewardTokenBalance(msg.sender);
    }

    function claimRewards() external nonReentrant whenNotPaused {
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount > 0, "No staked amount");

        _updateReward(msg.sender);

        uint256 pendingReward = staker.rewardDebt;
        staker.rewardDebt = 0; // Reset reward debt to 0

        if (pendingReward > 0) {
            require(rewardToken.balanceOf(address(this)) >= pendingReward, "Insufficient reward tokens");
            bool rewardTransferSuccess = rewardToken.transfer(msg.sender, pendingReward);
            require(rewardTransferSuccess, "Reward transfer failed");
            totalRewardTokenBalance -= pendingReward; // Update total reward token balance
        }

        _checkUserRewardTokenBalance(msg.sender);
    }

    // Internal functions
    function _updateReward(address _staker) internal {
        Staker storage staker = stakers[_staker];
        if (staker.stakedAmount > 0) {
            uint256 reward = _calculateReward(_staker);
            staker.rewardDebt += reward; // Accumulate the calculated reward
        }
    }

    function _calculateReward(address _staker) internal view returns (uint256) {
        Staker storage staker = stakers[_staker];
        uint256 stakedDuration = block.timestamp - staker.lastStakedTime;
        uint256 reward = (staker.stakedAmount * monthlyRewardPercentage * stakedDuration) / (30 days * 100);
        return reward;
    }

    function _checkUserRewardTokenBalance(address _staker) internal {
        Staker storage staker = stakers[_staker];
        uint256 pendingReward = staker.rewardDebt;
        uint256 balance = rewardToken.balanceOf(address(this));
        
        if (balance < pendingReward) {
            stakingPaused = true; // Pause staking if there are insufficient reward tokens
        }
    }

    // View functions
    function APY() external view returns (uint256) {
        return (12 * monthlyRewardPercentage);
    }

    function getMonthlyRewardPercentage() external view returns (uint256) {
        return monthlyRewardPercentage;
    }

    function checkOtherERC20Tokens(address _tokenAddress) external view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress);
        return token.balanceOf(address(this));
    }

    function getUserView(address _user) external view returns (uint256 stakedAmount, uint256 pendingRewards, uint256 unpaidRewards) {
        Staker storage staker = stakers[_user];
        uint256 duration = block.timestamp - staker.lastStakedTime;
        if (staker.lastPauseTime != 0 && staker.lastPauseTime > staker.lastStakedTime) {
            duration -= (block.timestamp - staker.lastPauseTime); // Adjust for paused duration
        }
        uint256 monthlyReward = (staker.stakedAmount * monthlyRewardPercentage) / 100;
        uint256 reward = (monthlyReward * duration) / 30 days;
        return (staker.stakedAmount, staker.rewardDebt + reward, staker.unpaidRewards);
    }

    function totalStaked() external view returns (uint256) {
        return totalStakedBalance;
    }

    function contractRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function ownerAddress() external view returns (address) {
        return owner();
    }

    function isStakingPaused() external view returns (bool) {
        return stakingPaused;
    }

    event InsufficientRewardTokens(address indexed staker, uint256 pendingReward);
}
