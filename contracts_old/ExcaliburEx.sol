pragma solidity >=0.4.21;

import "./ExcaliburDLL.sol";

contract Token {
  /// @notice send `_value` token to `_to` from `msg.sender`
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transfer(address _to, uint256 _value) returns (bool success) {}

  /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
  /// @param _from The address of the sender
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}
}

// Ex SC for Decentralized Liquidity Layer (DLL)
// prototype from 01.27.19 (without tradeBalances)
contract ExcaliburEx is SafeMath {

  address public admin;
  address public dllContract;
  bool public tradeState;
  

  mapping (address => mapping (address => uint)) public tokens; // mapping of token addresses to mapping of account balances (token=0 means Ether)

  event RequestOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, bytes32 hash);
  event RequestCancel(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s, bytes32 hash, string pair);
  event RequestTrade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, address get, address give, bytes32 hash, string pair);
  event Deposit(address token, address user, uint amount, uint balance);
  event Withdraw(address token, address user, uint amount, uint balance);


  function ExcaliburEx() {
      admin = msg.sender;
      tradeState = true;
  }

  modifier onlyAdmin {
        if (msg.sender != admin) throw;
        _;
  }

  modifier tradeIsOpen {
        if (!tradeState) throw;
        _;
  }

//   function checkAdmin() onlyAdmin returns (bool) {
//     return true;
//   }

  function transferOwnership(address newAdmin) onlyAdmin {
    admin = newAdmin;
  }

  function changeTradeState(bool state_) onlyAdmin {
    tradeState = state_;
  }

  function deposit() payable tradeIsOpen {
    // 0x0000000000000000000000000000000000000000
    tokens[0][msg.sender] = safeAdd(tokens[0][msg.sender], msg.value);
    Deposit(0, msg.sender, msg.value, tokens[0][msg.sender]);
  }

  function withdraw(uint amount) {
    if (tokens[0][msg.sender] < amount) throw;
    tokens[0][msg.sender] = safeSub(tokens[0][msg.sender], amount);
    if (!msg.sender.call.value(amount)()) throw;
    Withdraw(0x0000000000000000000000000000000000000000, msg.sender, amount, tokens[0][msg.sender]);
  }

  function depositToken(address token, uint amount) tradeIsOpen {
    // remember to call Token(address).approve(this, amount) or this contract will not be able to do the transfer on your behalf.
    if (token==0) throw;
    if (!Token(token).transferFrom(msg.sender, this, amount)) throw;
    tokens[token][msg.sender] = safeAdd(tokens[token][msg.sender], amount);
    Deposit(token, msg.sender, amount, tokens[token][msg.sender]);
  }

  function withdrawToken(address token, uint amount) {
    if (token==0) throw;
    if (tokens[token][msg.sender] < amount) throw;
    tokens[token][msg.sender] = safeSub(tokens[token][msg.sender], amount);
    if (!Token(token).transfer(msg.sender, amount)) throw;
    Withdraw(token, msg.sender, amount, tokens[token][msg.sender]);
  }

  function balanceOf(address token, address user) returns (uint) {
    return tokens[token][user];
  }

  function order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce) {
    ExcaliburDLL dll = ExcaliburDLL(dllContract);
    dll.order(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, admin);
  }

  function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s, uint amount, string pair) {
    // amount is in amountGet terms
    ExcaliburDLL dll = ExcaliburDLL(dllContract);
    dll.trade(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, admin, user, v, r, s, amount, pair);
  }

 // function tradeBalances(address tokenGet, uint amountGet, address tokenGive, uint amountGive, address user, uint amount) private {
 //   tokens[tokenGet][msg.sender] = safeSub(tokens[tokenGet][msg.sender], amount);
 //   tokens[tokenGet][user] = safeAdd(tokens[tokenGet][user], amount);
 //   tokens[tokenGive][user] = safeSub(tokens[tokenGive][user], safeMul(amountGive, amount) / amountGet);
 //   tokens[tokenGive][msg.sender] = safeAdd(tokens[tokenGive][msg.sender], safeMul(amountGive, amount) / amountGet);
 // }


  function cancelOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, uint8 v, bytes32 r, bytes32 s, string pair) {
    ExcaliburDLL dll = ExcaliburDLL(dllContract);
    dll.cancelOrder(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, admin, v, r, s, pair);
  }
}
