// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);
}

contract SentimentAI is Context, IERC20, Ownable {
    uint256 private constant _totalSupply = 1_000_000_000e18;
    uint256 private constant onePercent = 10_000_000e18;
    uint256 private minSwap = 250_000e18;
    uint256 public _minSwap;
    uint8 private constant _decimals = 18;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    IUniswapV2Router02 public sushiswapV2Router;
    address public sushiswapV2Pair;
    IUniswapV2Router02 public pancakeswapV2Router;
    address public pancakeswapV2Pair;

    address public WETH;
    address payable public marketingWallet;

    uint256 public buyTax;
    uint256 public sellTax;

    uint8 private launch;
    uint8 private inSwapAndLiquify;

    uint256 private launchBlock;
    uint256 public maxTxAmount = onePercent; //max Tx for first mins after launch

    string private constant _name = "SentimentAI";
    string private constant _symbol = "SENT";

    mapping(address => uint256) private _balance;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFeeWallet;

    constructor() {
        buyTax = 15;
        sellTax = 15;

        marketingWallet = payable(address(0));
        _balance[msg.sender] = _totalSupply;
        _isExcludedFromFeeWallet[msg.sender] = true;
        _isExcludedFromFeeWallet[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    modifier onlyOwnerOrMarketing() {
        require(
            _msgSender() == owner() || _msgSender() == marketingWallet,
            "Caller is not the owner or marketing wallet"
        );
        _;
    }

    function setMinSwap(uint256 newMinSwap) external onlyOwner {
        _minSwap = newMinSwap;
    }

    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        require(_marketingWallet != address(0), "Invalid marketing wallet address");
        marketingWallet = payable(_marketingWallet);
        _isExcludedFromFeeWallet[marketingWallet] = true;
    }

    function setUniswapRouter(address router) external onlyOwner {
        uniswapV2Router = IUniswapV2Router02(router);
        WETH = uniswapV2Router.WETH();
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), WETH);
        _allowances[address(this)][address(uniswapV2Router)] = type(uint256).max;
        _allowances[msg.sender][address(uniswapV2Router)] = type(uint256).max;
        _allowances[marketingWallet][address(uniswapV2Router)] = type(uint256).max;
    }

    function setSushiswapRouter(address router) external onlyOwner {
        sushiswapV2Router = IUniswapV2Router02(router);
        WETH = sushiswapV2Router.WETH();
        sushiswapV2Pair = IUniswapV2Factory(sushiswapV2Router.factory()).createPair(address(this), WETH);
        _allowances[address(this)][address(sushiswapV2Router)] = type(uint256).max;
        _allowances[msg.sender][address(sushiswapV2Router)] = type(uint256).max;
        _allowances[marketingWallet][address(sushiswapV2Router)] = type(uint256).max;
    }

    function setPancakeswapRouter(address router) external onlyOwner {
        pancakeswapV2Router = IUniswapV2Router02(router);
        WETH = pancakeswapV2Router.WETH();
        pancakeswapV2Pair = IUniswapV2Factory(pancakeswapV2Router.factory()).createPair(address(this), WETH);
        _allowances[address(this)][address(pancakeswapV2Router)] = type(uint256).max;
        _allowances[msg.sender][address(pancakeswapV2Router)] = type(uint256).max;
        _allowances[marketingWallet][address(pancakeswapV2Router)] = type(uint256).max;
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balance[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function openTrading() external onlyOwner {
        launch = 1;
        launchBlock = block.number;
    }

    function addExcludedWallet(address wallet) external onlyOwner {
        _isExcludedFromFeeWallet[wallet] = true;
    }

    function removeLimits() external onlyOwner {
        maxTxAmount = _totalSupply;
    }

    function changeTax(uint256 newBuyTax, uint256 newSellTax) external onlyOwner {
        buyTax = newBuyTax;
        sellTax = newSellTax;
    }

    function claimStuckedERC20(address tokenAddress, uint256 amount) external onlyOwnerOrMarketing {
        IERC20(tokenAddress).transfer(_msgSender(), amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 1e9, "Min transfer amt");

        uint256 _tax;
        if (_isExcludedFromFeeWallet[from] || _isExcludedFromFeeWallet[to]) {
            _tax = 0;
        } else {
            require(
                launch != 0 && amount <= maxTxAmount,
                "Launch / Max TxAmount 2% at launch"
            );

            if (inSwapAndLiquify == 1) {
                //No tax transfer
                _balance[from] -= amount;
                _balance[to] += amount;

                emit Transfer(from, to, amount);
                return;
            }

            if (from == uniswapV2Pair || from == sushiswapV2Pair || from == pancakeswapV2Pair) {
                _tax = buyTax;
            } else if (to == uniswapV2Pair || to == sushiswapV2Pair || to == pancakeswapV2Pair) {
                uint256 tokensToSwap = _balance[address(this)];
                if (tokensToSwap > _minSwap && inSwapAndLiquify == 0) {
                    if (tokensToSwap > onePercent) {
                        tokensToSwap = onePercent;
                    }
                    inSwapAndLiquify = 1;
                    address[] memory path = new address[](2);
                    path[0] = address(this);
                    path[1] = WETH;

                    // Select the appropriate router for the swap
                    if (to == uniswapV2Pair) {
                        uniswapV2Router
                            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                                tokensToSwap,
                                0,
                                path,
                                marketingWallet,
                                block.timestamp
                            );
                    } else if (to == sushiswapV2Pair) {
                        sushiswapV2Router
                            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                                tokensToSwap,
                                0,
                                path,
                                marketingWallet,
                                block.timestamp
                            );
                    } else if (to == pancakeswapV2Pair) {
                        pancakeswapV2Router
                            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                                tokensToSwap,
                                0,
                                path,
                                marketingWallet,
                                block.timestamp
                            );
                    }

                    inSwapAndLiquify = 0;
                }
                _tax = sellTax;
            } else {
                _tax = 0;
            }
        }

        //Is there tax for sender|receiver?
        if (_tax != 0) {
            //Tax transfer
            uint256 taxTokens = (amount * _tax) / 100;
            uint256 transferAmount = amount - taxTokens;

            _balance[from] -= amount;
            _balance[to] += transferAmount;
            _balance[address(this)] += taxTokens;
            emit Transfer(from, address(this), taxTokens);
            emit Transfer(from, to, transferAmount);
        } else {
            //No tax transfer
            _balance[from] -= amount;
            _balance[to] += amount;

            emit Transfer(from, to, amount);
        }
    }

    receive() external payable {}
}
