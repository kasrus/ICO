//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

interface ERC20Interface {
    function totalSupply() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

}

contract Cryptos is ERC20Interface{
    string public name = "Cryptos";
    string public symbol = "CRPT";
    uint public decimals = 0; //18 is the most common
    uint public override totalSupply; 

    address public founder;
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed; //allowing other accounts to spend
    //format to access it: allowed[0x111][0x222] = 100;

    constructor() {
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address _owner) public view override returns (uint256) {
        return balances[_owner];
    }

    //used to transfer by the owner to transfer his own token to another account
    //VIRTUAL keyword means that the function can change its behavior in the derived contracts by overriding
    function transfer(address to, uint256 tokens) public virtual override returns (bool) {
        require(balances[msg.sender] >= tokens);

        balances[to] += tokens;
        balances[msg.sender] -= tokens;

        emit Transfer(msg.sender, to, tokens);

        return true;
    }

    function allowance(address _owner, address _spender) public view override returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    //allows spender to withdraw from the account multiple times up to the tokens amount
    function approve(address spender, uint256 tokens) public override returns (bool success) {
        require(balances[msg.sender] >= tokens);
        require(tokens > 0);

        //giving allowance to the spender
        allowed[msg.sender][spender] = tokens;

        emit Approval(msg.sender, spender, tokens);

        return true;
    }

    //called by the account that wants to withdraw tokens from the holder's account to his own
    // The transferFrom method is used to allow contracts to spend
    // tokens on your behalf
    // Decreases the balance of "from" account
    // Decreases the allowance of "msg.sender"
    // Increases the balance of "to" account
    // Emits Transfer event
    //VIRTUAL keyword
    function transferFrom(address from, address to, uint256 tokens) public virtual override returns (bool) {
        require(allowed[from][msg.sender] >= tokens);
        require(balances[from] >= tokens);

        balances[from] -= tokens;
        balances[to] += tokens;
        allowed[from][msg.sender] -= tokens;

        emit Transfer(from, to, tokens);
        
        return true;
    }
}

contract CryptosICO is Cryptos {
    address public admin;
    address payable public deposit;
    uint tokenPrice = 0.001 ether; //1ETH = 1000 CRPT, 1CRPT = 0.001ETH
    uint public hardCap = 300 ether;
    uint public raisedAmount;
    uint public saleStart = block.timestamp; //If ICO starting in an hour block.timestamp + 3600
    uint public saleEnd = block.timestamp + 604800; //in one week
    
    //make the ico only transferable after the ICO offer ends
    uint public tokenTradeStart = saleEnd + 604800; //transferable in a week after the sale
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    enum State {beforeStart, running, afterEnd, halted}
    State public icoState;


    constructor (address payable _deposit) {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function halt() public onlyAdmin {
        icoState = State.halted;
    }

    function resume() public onlyAdmin {
        icoState = State.running;
  
    }

    //when the ICO get compromised
    function changeDepositAddress(address payable newDeposit) public onlyAdmin {
        deposit = newDeposit;
    }

    function getCurrentState() public view returns(State) {
        if(icoState == State.halted) {
            return State.halted;
        } else if (block.timestamp < saleStart) {
            return State.beforeStart; 
        } else if (block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return State.running;
        } else {
            return State.afterEnd;
        }
    }

    event Invest(address investor, uint value, uint token);

    //called when somebody sends ETH to the contract & receives cryptos in return
    function invest() payable public returns(bool) {
        //ICO should be in running state
        icoState = getCurrentState();
        require(icoState == State.running);
    
        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap);
         
        uint tokens = msg.value / tokenPrice;
        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value);

        emit Invest(msg.sender, msg.value, tokens);
        return true;
    }

    receive ()payable external {
        invest();
    }
 
    function transfer(address to, uint256 tokens) public override returns (bool) {
        require(block.timestamp > tokenTradeStart);
        //Cryptos.transfer(to, tokens);
        super.transfer(to, tokens); //same as Cryptos.transfer();
        return true;   
    }

    function transferFrom(address from, address to, uint256 tokens) public override returns (bool) {
        require(block.timestamp > tokenTradeStart);
        super.transferFrom(from, to, tokens);

        return true;
    }

    function burn() public returns(bool) {
        icoState = getCurrentState();
        require(icoState == State.afterEnd);

        //setting the founder's balance to 0
        balances[founder] = 0;

        return true;
    }

}
