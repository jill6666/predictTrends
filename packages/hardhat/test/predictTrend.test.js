describe("My Dapp", function () {
  /**
   * - round should be started automatically by chainlilnk at 20:00 in every day
   * - round info should be setup only by admin
   *    - shotPrice
   *    - refundFee
   *    - claimFee
   * - order should be created by user
   * - order should be updated by user
   * - order should be refunded by user
   * - round should be locked automatically by chainlilnk at 16:00 in every day
   * - executed should be triggered automatically by chainlilnk at 16:00 in every day
   * - admin should withdraw value from the contract
   */
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
});
