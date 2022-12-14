# Predict Trends

## About

### What

### Why

### How

## System Design

```
contracts
|_ PredictTrends.sol
|_ PredictTrendsInterface.sol
|_ SafeMath.sol
```

### storages

```solidity
contract PredictTrendsStorage {
    /*** Predict Trends Storage ***/

    uint256 upAmountSum; // 賭漲的總 shot 數
    uint256 downAmountSum; // 賭跌的總 shot 數

    // How to make sure the interval is exactly same as chainlink time-based automation?
    uint256 start_interval = 43200; // 12hr
    uint256 execute_interval = 39600; // 11hr

    uint256 public shotPrice = 1000000000000; // 一注多少 eth 1000000000000 == 0.000001 ether
    uint256 public refundFee = 5; // 退款手續費 5 %
    uint256 public claimFee = 1; // 領獎手續費 1 %
    
    uint256 public roundBlockNumber = 0; // 進行到第幾 round, 0 based

    bool public inProgress = false; // 回合進行中

    enum Trend {down, up, hold} // hold is a edge case

    struct OrderInfo {
        uint256 shot; // 多少注
        Trend trend; // 漲或跌 (0 跌 1 漲)
    }
    struct RoundInfo {
        int startPrice; // 回合開始時的當前價格
        int endPrice; // 回合結束時的當前價格
        uint256 startTime;
        uint256 endTime;
        Trend trendResult; // 漲或跌 (0 跌 1 漲)
    }
    
    /** roundId => user.address => {uint256 shot, bool trend} */
    mapping(uint256 => mapping(address => OrderInfo)) public roundOrderInfo;

    /** roundId => 回合開始時跟結束時的當前價格 */
    mapping(uint256 => RoundInfo) public roundPriceInfo;
}
```

### interface

```solidity
abstract contract PredictTrendsInterface is PredictTrendsStorage {
    AggregatorV3Interface internal priceFeed;
        
    /**
     * Network: Goerli
     * Aggregator: ETH/USD
     * Address: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
     */
    constructor() {
        priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        );
    }

    /*** User Interface ***/
    function userClaim(uint256 _roundBlockNumber) virtual external returns(bool);
    function createOrder(uint256 _shot, bool _trend) virtual external payable;
    function updateOrder(uint256 _shot, bool _trend) virtual external payable;
    function refundOrder() virtual external;
    function _getTrendResult(int _startPrice, int _endPrice) virtual internal returns (Trend);
    function _setRecordInfo(uint256 _shot, bool _trend) virtual internal ;

    /*** Admin Functions ***/
    function startNewRound() virtual external;
    function executeRoundResult() virtual external;
    function setShotPrice(uint256 _price) virtual external;
    function withdraw(uint256 _amount) virtual external;
    function _resetState() virtual internal;

    /*** Utils ***/

    function _isContract(address addr) view internal returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function _safeTransferETH(address _to, uint256 _value) internal {
        (bool success, ) = _to.call{value: _value}(new bytes(0));
        require(success, "Failed to send Ether");
        emit Transfer(_to, _value);
    }

    /** Returns the latest price */
    function _getPrice() view internal returns (int) {
        (
            ,
            /*uint80 roundID*/ int price /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = priceFeed.latestRoundData();
        return price;
    }

		/** modifiers */

    modifier nonContractCall(address addr) {
        require(!_isContract(addr), "ERROR: Only EOA can enteract with.");
        _;
    }

    modifier onlyInProgress() {
        require(inProgress, "ERROR: Need to in progress.");
        _;
    }

    modifier notInProgress() {
        require(!inProgress, "ERROR: Not available when in progress.");
        _;
    }
}
```

### events

```solidity
abstract contract PredictTrendsInterface is PredictTrendsStorage {
    /*** PredictTrends Events ***/

    /**
     * @notice Event emitted when order is created
     */
    event CreateOrder(address orderer, uint256 shot, bool trend);

    /**
     * @notice Event emitted when order is updated
     */
    event UpdateOrder(address orderer, uint256 newShot, bool trend);

    /**
     * @notice Event emitted when order is refunded
     */
    event RefundOrder(address orderer, uint256 refundAmount, uint256 refundFee);

    /**
     * @notice Event emitted when order is claimed
     */
    event ClaimOrder(address orderer, uint256 value, uint256 share, uint256 shotPrice, uint256 shot);

    /**
     * @notice Event emitted when order is refunded in hold trend result
     */
    event RefundInHoldResult(address orderer, uint256 refundAmount);

    /**
     * @notice Event emitted when received value
     */
    event Received(address, uint256);

    /**
     * @notice Event emitted when transfer completed
     */
    event Transfer(address to, uint256 value);
    

    /*** Admin Events ***/

    /**
     * @notice Event emitted when round is started
     */
    event RoundStarted(uint256 interval, uint256 roundBlockNumber, uint256 shotPrice, uint256 refundFee);

    /**
     * @notice Event emitted when order is end
     */
    event executeResult(int startPrice, int endPrice, Trend trendResult);
    
    /**
     * @notice Event emitted when token in contract is withdraw by admin
     */
    event Withdraw(address to, uint256 withdrawAmount);

    /**
     * @notice Event emitted when the shotPrice is changed
     */
    event SetShotPrice(address operator, uint256 shotPrice);
		
		// ...
}
```

### main contract

### Time-Based Automation
![predictTrends@2x (1)](https://user-images.githubusercontent.com/73696750/207617658-a73aba96-8e92-43eb-9c06-86937b1945fe.png)

## Testing on Chain

### test case
![predictTrends@2x (3)](https://user-images.githubusercontent.com/73696750/207617604-59f5f184-4006-42e4-9af9-9633501d051e.png)


```jsx
/** 🎅: admin, 👾: user
   * NOT IN PROGRESS
   *✅ 🎅 deploy contract
   *✅ 1. 🎅 set shotPrice 1000000000000 wei
   *✅    - read shotPrice, it should be 1000000000000 wei
   *✅ 3. read roundBlockNumber, it should be 0
   *✅ 4. read refundFee, it should be 5 (initial value)
   *✅ 5. read inProgress, it should be false
   *✅ 6. read claimFee, it should be 1 (initial value)
   *✅ 7. [x] createNewOrder, it should be reverted
   *TODO: 8. [x] executeRoundResult, it should be reverted
   *✅ 9. [x] refundOrder, it should be reverted
   *✅ 10. userClaim, if caller is the winner, caller should receive 99% bonus of value
   *
   * INPROGRESS
   * 🎅 startNewRound()
   *✅ 1. read roundBlockNumber, it should be 1
   *✅ 2. read inProgress, it should be true
   *✅ 3. read roundPriceInfo, its startPrice should grater than 0
   *✅ 4. createNewOrder
   *✅    -  SUCCESS: read roundOrderInfo[blockNumber][msg.sender], its shot should to grater than 0
   *✅ 4-1. refundOrder
   *✅      - SUCCESS: order is exceeded and refund 95% value to customer
   *✅      - ERROR: there is no order created
   *✅ 5. executeRoundResult
   *✅    -  SUCCESS: times up, execute the result
   *✅        - read roundPriceInfo, the endPrice should grater than 0
   *✅        - read inProgress, it should be false
   *✅        - upAmountSum and downAmountSum should be reset to 0
   *✅ 6. userClaim, if caller is the winner, caller should receive 99% bonus of value
   *✅ 7. [x] 🎅 startNewRound(), it should be reverted
*/
```

## Roadmap

- [ ]  complete the CICD flow
- [ ]  web3 development
- [ ]  write test with mock price data
