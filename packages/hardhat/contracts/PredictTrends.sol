// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SafeMath.sol";
import "./PredictTrendsInterface.sol";

// TODO:
//// 1. check if underflow for every calculation
//// 2. check number for 單位換算 eth to wei
//// 2. countdown
// 3. call executed off chain
// 4. deploy to Goerli
//// 5. test case (optional if time enough 🥲)
// 6. website (optional...)
//// 7. test on remix

contract PredictTrends is Ownable, PredictTrendsInterface {
    using SafeMath for uint256;
    
    /*** PredictTrends functions ***/

    /** user 建立一筆賭注 
     * @param _shot 下多少注
     * @param _trend 預測結果 false 跌 true 漲
    */
    function createOrder(uint256 _shot, bool _trend) override public payable nonContractCall(msg.sender) onlyInProgress {
        require(_shot > 0, "ERROR: Shot amount must be greater than 0.");

        if(roundOrderInfo[roundBlockNumber][msg.sender].shot > 0) updateOrder(_shot, _trend);
        else {
            require(msg.value >= _shot * shotPrice, "ERROR: Your ETH is not enough");
            
            _setRecordInfo(_shot, _trend);
            emit CreateOrder(msg.sender, _shot, _trend);
        }
    }

    /** user 加碼下注，不能減少下注額，只能增加
     * @param _shot 再下多少注
     * @param _trend 預測結果 false 跌 true 漲
    */
   // TODO: public
    function updateOrder(uint256 _shot, bool _trend) override public payable nonContractCall(msg.sender) onlyInProgress {
        uint256 originalShot = roundOrderInfo[roundBlockNumber][msg.sender].shot;
        uint256 newShot = originalShot + _shot;

        require(msg.value >= _shot * shotPrice, "ERROR: Your ETH is not enough.");
        require(newShot >= originalShot, "ERROR: New shot should be greater than original shot.");

        _setRecordInfo(newShot, _trend);
        emit UpdateOrder(msg.sender, newShot, _trend);
    }

    /** user 不想玩了，可退但要收手續費 */
    function refundOrder() override public nonContractCall(msg.sender) onlyInProgress {
        uint256 _shot = roundOrderInfo[roundBlockNumber][msg.sender].shot;
        require(_shot > 0, "ERROR: The order not found.");

        delete roundOrderInfo[roundBlockNumber][msg.sender];
        
        uint256 refundAmount = (_shot * shotPrice * (100 - refundFee)).div(100);
        _safeTransferETH(msg.sender, refundAmount);

        emit RefundOrder(msg.sender, refundAmount, refundFee);
    }

    /** 紀錄這筆交易的內容，誰、賭多少、賭什麼 */
    function _setRecordInfo(uint256 _shot, bool _trend) override internal {
        roundOrderInfo[roundBlockNumber][msg.sender].shot = _shot;
        roundOrderInfo[roundBlockNumber][msg.sender].trend = _trend ? Trend.up : Trend.down;

        if(_trend) upAmountSum + _shot;
        else downAmountSum + _shot;
    }

    /** 贏家來兌獎計算他的 share 、可以拿多少錢，輸家直接 revert */
    function userClaim(uint256 _roundBlockNumber) override public nonContractCall(msg.sender) returns(bool) {
        uint256 _shot = roundOrderInfo[_roundBlockNumber][msg.sender].shot;
        int _startPrice = roundPriceInfo[_roundBlockNumber].startPrice;
        int _endPrice = roundPriceInfo[_roundBlockNumber].endPrice;
        Trend _trend = roundOrderInfo[_roundBlockNumber][msg.sender].trend;
        Trend _resultTrend = roundPriceInfo[_roundBlockNumber].trendResult;
        uint256 _winnerShotSum = _resultTrend == Trend.down ? downAmountSum : _resultTrend == Trend.up ? upAmountSum : 0;
        uint256 _loserShotSum = _resultTrend == Trend.down ? upAmountSum : _resultTrend == Trend.up ? downAmountSum : 0;
        bool isHoldTrend = _resultTrend == Trend.hold;

        require(_startPrice > 0, "ERROR: The round is not started.");
        require(_endPrice > 0, "ERROR: The round is not in the end.");
        require(_shot > 0, "ERROR: You have no order for this round.");
        require(_trend == _resultTrend || isHoldTrend, "ERROR: So sad, you are not the winner of this round.");

        uint256 refundAmount = _shot * shotPrice;
        if(isHoldTrend) return _holdTrendRefund(refundAmount);

        if(_winnerShotSum == 0 || _loserShotSum == 0) {
            // refund directly
            uint256 rewardAmount = (_shot * shotPrice * (100 - claimFee)).div(100);
            _safeTransferETH(msg.sender, rewardAmount);
            emit ClaimOrder(msg.sender, rewardAmount, 0, shotPrice, _shot);
            return true;
        } else {
            uint256 share = ((_loserShotSum * shotPrice).div(_winnerShotSum) * (100 - claimFee)).div(100);
            uint256 rewardAmount = _shot * share;

            _safeTransferETH(msg.sender, rewardAmount);
            emit ClaimOrder(msg.sender, rewardAmount, share, shotPrice, _shot);
            return true;
        }
    }

    function _holdTrendRefund(uint256 _amount) private returns(bool) {
        emit RefundInHoldResult(msg.sender, _amount);
        _safeTransferETH(msg.sender, _amount);
        return true;
    }

    /*** Admin functions ***/

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

    function _getTrendResult(int _startPrice, int _endPrice) override pure internal returns (Trend) {
        int256 diff = _endPrice - _startPrice;

        if(diff == 0) return Trend.hold;
        else if(diff > 0) return Trend.up;
        else return Trend.down;
    }

    function _resetState() override internal {
        upAmountSum = 0;
        downAmountSum = 0;
        inProgress = false;
    }

    /** 設定一注多少錢 */
    function setShotPrice(uint256 _price) override public onlyOwner notInProgress {
        require(_price > 0, "ERROR: Price must be greater than 0.");
        shotPrice = _price;
        emit SetShotPrice(msg.sender, _price);
    }

    /** TODO: 權限會不會太大？ owner 想要在什麼時候領多少錢出來都可以，怎麼設計比較好？ */
    function withdraw(uint256 _amount) override public onlyOwner {
        _safeTransferETH(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}