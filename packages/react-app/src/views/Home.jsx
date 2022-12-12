import { useContractReader } from "eth-hooks";
import { ethers } from "ethers";
import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { Button, Typography } from "antd";
import { homePageConfig } from "../dataa/config";

/**
 * web3 props can be passed from '../App.jsx' into your local view component for use
 * @param {*} yourLocalBalance balance on current network
 * @param {*} readContracts contracts from current chain already pre-loaded using ethers contract module. More here https://docs.ethers.io/v5/api/contract/contract/
 * @returns react component
 **/
function Home({ yourLocalBalance, readContracts }) {
  const [buttons, setButtons] = useState(homePageConfig.button);

  /**
   * @param {"creat"|"refund"|"claim"} btnType
   * @param {"loading"|"disabled"} action
   * @param {Boolean} state
   */
  const handleButtonState = (btnType, action, state) => {
    setButtons(prev => ({ ...prev, [btnType]: { ...prev[btnType], [action]: state } }));
  };

  return (
    <div>
      <Typography.Title level={1}>{homePageConfig.title}</Typography.Title>
      <div className="space-x-4">
        {Object.values(buttons).map(item => (
          <Button key={item.id} icon={item.icon} disabled={item.disabled} loading={item.loading}>
            {item.displayName}
          </Button>
        ))}
      </div>
    </div>
  );
}

export default Home;
