// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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

contract HolderBonusPool is ReentrancyGuard, Ownable, Pausable {
    IERC20 public rewardToken;
    IERC20 public holdToken;

    uint256 public WeeklyRewardPerBillion;
    uint256 public minimumHeldAmount;
    uint256 public minimumHeldTime;

    struct UserInfo {
        uint256 holdTokenBalance;
        uint256 lastUpdate;
        uint256 pendingReward;
        uint256 lastHeldTime; // To track the last time the minimum held time was met
    }

    mapping(address => UserInfo) public userInfos;

    constructor(IERC20 _holdToken, IERC20 _rewardToken, address initialOwner) 
        Ownable(initialOwner) // Pass initialOwner to Ownable
    {
        holdToken = _holdToken;
        rewardToken = _rewardToken;
    }

    function updateWeeklyRewardPerBillion(uint256 newRewardPerBillion) external onlyOwner {
        WeeklyRewardPerBillion = newRewardPerBillion;
    }

    function updateEligibilityCriteria(uint256 newHeldAmount, uint256 newHeldTime) external onlyOwner {
        minimumHeldAmount = newHeldAmount;
        minimumHeldTime = newHeldTime;
    }

    function updateReward() external nonReentrant whenNotPaused {
        UserInfo storage user = userInfos[msg.sender];
        uint256 balance = holdToken.balanceOf(msg.sender);
        require(balance >= minimumHeldAmount, "Insufficient holdToken balance");

        uint256 elapsedTime = block.timestamp - user.lastUpdate;
        require(elapsedTime >= minimumHeldTime, "Minimum held time not met");

        uint256 reward = calculateProportionalReward(balance, elapsedTime);
        user.pendingReward += reward;

        user.holdTokenBalance = balance;
        user.lastUpdate = block.timestamp;
        user.lastHeldTime = block.timestamp; // Reset the last held time
    }

    function claimReward() external nonReentrant whenNotPaused {
        UserInfo storage user = userInfos[msg.sender];
        uint256 reward = user.pendingReward;
        require(reward > 0, "No reward to claim");

        user.pendingReward = 0;
        rewardToken.transfer(msg.sender, reward);
    }

    function calculateProportionalReward(uint256 balance, uint256 elapsedTime) internal view returns (uint256) {
        uint256 oneBillionHoldToken = 1e9 * 1e18; // 1 billion holdToken in Wei
        uint256 weeklyReward = (balance / oneBillionHoldToken) * WeeklyRewardPerBillion;
        uint256 proportionalReward = (weeklyReward * elapsedTime) / 604800; // Proportional reward based on time elapsed (604800 seconds in a week)
        return proportionalReward;
    }

    function depositRewardToken(uint256 amount) external onlyOwner {
        rewardToken.transferFrom(msg.sender, address(this), amount);
    }

    function getUserView(address userAddress) external view returns (uint256 holdTokenBalance, uint256 pendingReward, uint256 APY) {
        UserInfo storage user = userInfos[userAddress];
        return (user.holdTokenBalance, user.pendingReward, calculateAPY());
    }

    function calculateAPY() internal view returns (uint256) {
        return WeeklyRewardPerBillion * 52 / 1e18; // APY based on weekly reward per billion
    }

    function rewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function withdrawAllRewardToken() external onlyOwner {
        uint256 amount = rewardToken.balanceOf(address(this));
        require(rewardToken.transfer(msg.sender, amount), "Token transfer failed");
    }

    function checkOtherERC20Tokens(IERC20 token) external view returns (uint256) {
        require(address(token) != address(rewardToken) && address(token) != address(holdToken), "Token is rewardToken or holdToken");
        return token.balanceOf(address(this));
    }

    // Emergency functions for contract management, if needed
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Function to withdraw tokens mistakenly sent to the contract
    // (Consider the security implications and use cases of such a function)
    function withdrawToken(IERC20 token, uint256 amount) external onlyOwner {
        require(address(token) != address(rewardToken) && address(token) != address(holdToken), "Token is rewardToken or holdToken");
        require(token.transfer(msg.sender, amount), "Token transfer failed");
    }

    function withdrawStuckETH() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance in contract");

        (bool success, ) = payable(_msgSender()).call{value: balance, gas: 30000}("");
        require(success, "Transfer failed.");
    }

    // Additional functions for contract management and optimization can be added here
}
