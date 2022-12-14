# Predict Trends
Contract on Goerli: [0xb38C582B56e17e105E451f4a9B968C9a21879bb8](https://goerli.etherscan.io/address/0xb38C582B56e17e105E451f4a9B968C9a21879bb8)

## About

### What is Predict Trends?

Predict Trends 是個在區塊鏈上的價格競猜遊戲，使用者可以在回合開放的時限內下注，預測幣價的漲跌。

回合時間到了會由在 chainlink 註冊的自動化服務觸發執行結果的 function，將答案算出來，若使用者預測正確，即可瓜分輸家的投注金額（詳細玩法見下方介紹）。

### Why do this?

選擇這個題目是因為博彩類型的遊戲是最令人著迷且招架不住的，
不論是最近世足賽事的運動彩券、大樂透，都是平易近人且富含娛樂的休閒活動。

### How does it work?

從 User Case 來看：

User 在回合進行中可以做的事情
![predictTrends@2x (2)](https://user-images.githubusercontent.com/73696750/207629967-e3052d4d-f670-43f2-bc1d-f241309348ab.png)

- Create Order:
    - 呼叫 `createOrder()` 方法並帶入所需 value
    - 創建訂單所需 value = shotPrice * shot
    - 一個地址只能預測一種結果
- Update Order:
    - 若創建訂單後要修改訂單，只能加碼跟改預測結果，不能下修金額
    - 一樣是呼叫 `createOrder()` ，系統會更新在同一張單下
- Refund Order
    - 若創建訂單後要刪除訂單退款，系統將收取5% 手續費 😜
    - 呼叫 `refundOrder()` 獲得 95% 的退款

User 在回合結束後可以做的事情

- User Claim
    - 預測結果出來後，使用者必須自己來拿獎勵
    - 只能領取單局獎勵，不支援一鍵領取多局獎勵
    - 領取時系統將收取 1% 手續費 👻
    - 若該局結果為幣價值平，系統將不收取手續費

從系統角度來看：

> 先解釋系統儲存的兩個跟時間相關的變數
> - start_interval = 43200：12 小時（過 12 小時才可以再次呼叫 startNewRound）
> - execute_interval = 39600：11 小時（過 11 小時才可以再次呼叫 executeRoundResult）
> （會需要關閉一小時是設計來讓系統休息的）

開啟新的回合並且計時

- 檢查是否初始回合、上一局是否已經有了結束時間
- 通過才可以開始新的一局
- （不在 blockchain 上做 counter）

```solidity
/** 開啟新的一回合 */
    function startNewRound() override external notInProgress {
        require(shotPrice > 0, "ERROR: ShotPrice must be greater than 0.");
        require(roundBlockNumber == 0 || roundPriceInfo[roundBlockNumber].endTime > 0, "ERROR: It already has a round.");

        int _startPrice = _getPrice();
        // update state
        roundBlockNumber++;
        inProgress = true;
        roundPriceInfo[roundBlockNumber].startPrice = _startPrice;
        roundPriceInfo[roundBlockNumber].startTime = block.timestamp;

        emit RoundStarted(start_interval, roundBlockNumber, shotPrice, refundFee);
    }
```

時間到時結束該回合

- 檢查回合是否還在進行中（block.timestamp - _startTime > execute_interval）
- 檢查是否已經計算過結果了（roundPriceInfo[roundBlockNumber].endPrice > 0）

```solidity
/** 讓 chainlink time-based automation call in every day */
    function executeRoundResult() override external {
        uint256 _startTime = roundPriceInfo[roundBlockNumber].startTime;
        require(block.timestamp - _startTime > execute_interval, "ERROR: Cannot execute round result in progress.");
        require(roundPriceInfo[roundBlockNumber].endPrice > 0, "ERROR: Cannot re-execute in one round.");

        int _endPrice = _getPrice();
        int256 _startPrice = roundPriceInfo[roundBlockNumber].startPrice;
        Trend trendResult = _getTrendResult(_endPrice, _startPrice);

        roundPriceInfo[roundBlockNumber].endPrice = _endPrice;
        roundPriceInfo[roundBlockNumber].trendResult = trendResult;
        roundPriceInfo[roundBlockNumber].endTime = block.timestamp;

        _resetState();
        emit executeResult(_startPrice, _endPrice, trendResult);
    }
```
舉例來說，只要確保有人每天重複執行

- 00:00 呼叫 `startNewRound()` 方法
- 11:00 呼叫 `executeRoundResult()` 方法
- 12:00 再 `startNewRound()`
- 23:00 呼叫 `executeRoundResult()`  方法

就可以在 00:00-11:00 和 12:00-23:00 之間讓使用者下注，因此選擇了自動化的服務讓系統更佳地友善。

![predictTrends@2x (1)](https://user-images.githubusercontent.com/73696750/207617658-a73aba96-8e92-43eb-9c06-86937b1945fe.png)

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
    // events ...

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

    // ...

    /** modifiers */

    // ...
}
```

## Testing on Chain

### test case
![predictTrends@2x (3)](https://user-images.githubusercontent.com/73696750/207617604-59f5f184-4006-42e4-9af9-9633501d051e.png)


## Roadmap

- [ ]  verify the contract on Goerli etherscan
- [ ]  complete the CICD flow
- [ ]  web3 development
- [ ]  write test with mock price data
