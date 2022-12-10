// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SafeMath.sol";
import "./PredictTrendsInterface.sol";

// token = GoerliETH
contract PredictTrends is Ownable, PredictTrendsInterface {
    using SafeMath for uint256;

    /** 開啟新的一回合 */
    function startNewRound() override public onlyOwner notInProgress {
        inProgress = true;

        uint256 _startPrice = _getPrice();
        roundPriceInfo[roundBlockNumber].startPrice = _startPrice;

        emit RoundStarted(roundTime, roundBlockNumber, shotPrice, refundFee);
        _countdown();
    }

    function _countdown() private {
        // TODO: how to countdown on block chain?
    }

    function excuteRoundResult() override public {
        bool mockTimesup = false;

        if(mockTimesup) {
            uint256 _endPrice = _getPrice();
            uint256 _startPrice = roundPriceInfo[roundBlockNumber].startPrice;
            Trend trendResult = _getTrendResult(_endPrice, _startPrice);

            roundPriceInfo[roundBlockNumber].endPrice = _endPrice;
            roundBlockNumber++;

            _resetState();
            emit ExcuteResult(_startPrice, _endPrice, trendResult);
        }
    }

    function _getTrendResult(uint256 _startPrice, uint256 _endPrice) override pure internal returns (Trend) {
        uint256 diff = _endPrice - _startPrice;

        if(diff == 0) return Trend.hold;
        else if(diff > 0) return Trend.up;
        else return Trend.down;
    }

    function _resetState() override internal {
        upAmountSum = 0;
        downAmountSum = 0;
        inProgress = false;
    }

    /** 跟 chainlink 拿資訊 */
    function _getPrice() override pure internal returns(uint256) {
        uint256 mockPrice = 4000;
        return mockPrice;
    }


    /** 紀錄這筆交易的內容，誰、賭多少、賭什麼 */
    function _setRecordInfo(uint256 _shot, bool _trend) override internal {
        roundOrderInfo[roundBlockNumber][msg.sender].shot = _shot;
        roundOrderInfo[roundBlockNumber][msg.sender].trend = _trend ? Trend.up : Trend.down;

        if(_trend) upAmountSum + _shot;
        else downAmountSum + _shot;
    }

    /** 贏家來兌獎計算他的 share 、可以拿多少錢，輸家直接 revert */
    function userClaim() override public nonContractCall(msg.sender) notInProgress returns(bool) {
        uint256 shotAmount = roundOrderInfo[roundBlockNumber][msg.sender].shot * shotPrice;
        require(shotAmount > 0, "ERROR: You have no order for this round.");
        // TODO:
        uint256 mockPrice = 100;
        uint256 mockShare = 10;

        uint256 share = mockShare;
        uint256 bonusAmount = mockPrice;

        emit ClaimOrder(msg.sender, bonusAmount, share, shotPrice, roundOrderInfo[roundBlockNumber][msg.sender].shot);
        return token.transfer(msg.sender, bonusAmount);
    }

    /** user 建立一筆賭注 */
    function createOrder(uint256 _shot, bool _trend) override public nonContractCall(msg.sender) onlyInProgress {
        require(_shot > 0, "ERROR: Shot amount must be greater than 0.");
        require(token.balanceOf(msg.sender) >= _shot * shotPrice, "ERROR: your TST is not enough");

        if(roundOrderInfo[roundBlockNumber][msg.sender].shot > 0) _updateOrder(_shot, _trend);
        else {
            _setRecordInfo(_shot, _trend);
            emit CreateOrder(msg.sender, _shot, _trend);
        }
    }

    /** user 加碼下注 */
    function _updateOrder(uint256 _shot, bool _trend) override internal nonContractCall(msg.sender) onlyInProgress {
        uint256 originalShot = roundOrderInfo[roundBlockNumber][msg.sender].shot;
        uint256 newShot = originalShot + _shot;

        require(token.balanceOf(msg.sender) >= newShot * shotPrice, "ERROR: Your TST is not enough.");
        require(_shot >= originalShot, "ERROR: New shot should be greater than original shot.");

        _setRecordInfo(newShot, _trend);
        emit UpdateOrder(msg.sender, newShot, _trend);
    }

    /** user 不想玩了，可退但要收手續費 */
    function refundOrder() override public nonContractCall(msg.sender) onlyInProgress {
        uint256 _shot = roundOrderInfo[roundBlockNumber][msg.sender].shot;
        require(_shot > 0, "ERROR: No money to refund.");

        delete roundOrderInfo[roundBlockNumber][msg.sender];
        
        // TODO: underflow
        uint256 refundAmount = (_shot * shotPrice * refundFee) / 100;
        token.transfer(msg.sender, refundAmount);

        emit RefundOrder(msg.sender, refundAmount, refundFee);
    }

    /** 調整每回合的時長，是過了幾秒不是切確的時間 */
    function setRoundTime(uint256 _seconds) override public onlyOwner notInProgress {
        require(_seconds >= 300, "ERROR: Round time should be grater than or equal to 300 seconds.");
        roundTime = _seconds;
    }

    /** 設定一注多少錢 */
    function setShotPrice(uint256 _price) override public onlyOwner notInProgress {
        require(_price > 0, "ERROR: Price must be greater than 0.");
        shotPrice = _price;
        emit SetShotPrice(msg.sender, _price);
    }

    /** for emergency close */
    function setAvailable(bool _available) override public onlyOwner {
        available = _available;
        emit SetAvailable(msg.sender, _available);
    }

    function withdraw(uint256 _amount) override public  onlyOwner{
        emit Withdraw(msg.sender, _amount);
    }

    function _isContract(address addr) view internal returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    modifier nonContractCall(address addr) {
        require(!_isContract(addr), "ERROR: Only EOA can enteract with.");
        _;
    }

    modifier onlyInProgress() {
        require(available, "ERROR: Not available.");
        require(inProgress, "ERROR: Need to in progress.");
        _;
    }

    modifier notInProgress() {
        require(!inProgress, "ERROR: Not available when in progress.");
        _;
    }

    receive() external payable {}
}