pragma solidity >=0.4.25;

contract SafeMath {
  function safeMul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function safeSub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c>=a && c>=b);
    return c;
  }

  function assert(bool assertion) internal {
    if (!assertion) throw;
  }
}

contract AbstractExcaliburDLL is SafeMath {
    function order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange) external {
    // No implementation, just the function signature. This is just so Solidity can work out how to call it.
    }
    function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange, address user, uint8 v, bytes32 r, bytes32 s, uint amount, string pair) external {
    // No implementation, just the function signature. This is just so Solidity can work out how to call it.
    }
    function cancelOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange, uint8 v, bytes32 r, bytes32 s, string pair) external {
    // No implementation, just the function signature. This is just so Solidity can work out how to call it. 
    }
}

// Decentralized Liquidity Layer (DLL)
// prototype from 01.27.19 (without tradeBalances)
contract ExcaliburDLL is AbstractExcaliburDLL {
    
  address public admin;
  bool public tradeState;
  struct exchangeInfo {
        bool tradeStatus;
        string shortName;
        string fullName;
        string webLink;
  }
  
  mapping (address => exchangeInfo) public exchange_list; // list of exchanges connected to DLL
  mapping (address => mapping (address => mapping (bytes32 => bool))) public orders; // orders[exchange_adress][user_adress][hash]
  mapping (address => mapping (address => mapping (bytes32 => uint))) public orderFills; // orderFills[exchange_adress][user_adress][count_of_currency]

  event Order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange, address user, bytes32 hash);
  event Cancel(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange, address user, uint8 v, bytes32 r, bytes32 s, bytes32 hash, string pair);
  event Trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, address exchange, address get, address give, bytes32 hash, string pair);



  modifier onlyAdmin {
        if (msg.sender != admin) throw;
        _;
  }

  modifier tradeIsOpen {
        if (!tradeState) throw;
        _;
  }
  
  modifier exIsConnected {
        if (!(exchange_list[msg.sender].tradeStatus)) throw;
        _;
  }

//  function checkAdmin() onlyAdmin returns (bool) {
  //  return true;

  function transferOwnership(address newAdmin) onlyAdmin {
    admin = newAdmin;
  }

  function changeTradeState(bool state_) onlyAdmin {
    tradeState = state_;
  }

  function order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange) external exIsConnected {
    bytes32 hash = sha3(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, exchange);
    orders[exchange][msg.sender][hash] = true;
    Order(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, exchange, msg.sender, hash);
  }

  function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange, address user, uint8 v, bytes32 r, bytes32 s, uint amount, string pair) external exIsConnected {
    // amount is in amountGet terms
    bytes32 hash = sha3(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, exchange);
    if (!( (orders[exchange][user][hash] || ecrecover(sha3("\x19Ethereum Signed Message:\n32", hash),v,r,s) == user) && block.number <= expires && safeAdd(orderFills[exchange][user][hash], amount) <= amountGet)) throw;
    orderFills[exchange][user][hash] = safeAdd(orderFills[exchange][user][hash], amount);
    //Trade(tokenGet, amount, tokenGive, amountGive * amount / amountGet, user, msg.sender, hash, pair);
  }

  function cancelOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address exchange, uint8 v, bytes32 r, bytes32 s, string pair) external exIsConnected {
    bytes32 hash = sha3(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, exchange);
    if (!(orders[exchange][msg.sender][hash] || ecrecover(sha3("\x19Ethereum Signed Message:\n32", hash),v,r,s) == msg.sender)) throw;
    orderFills[exchange][msg.sender][hash] = amountGet;
    Cancel(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, exchange, msg.sender, v, r, s, hash, pair);
  }
}
