import mockData from "./mockData";
import { PlusOutlined, RollbackOutlined, GiftOutlined } from "@ant-design/icons";

export const homePageConfig = {
  title: "Predict Trends",
  button: {
    create: { displayName: "Create", icon: <PlusOutlined />, disabled: false, isLoading: false, color: "#fecaca" },
    refund: { displayName: "Refund", icon: <RollbackOutlined />, disabled: false, isLoading: false, color: "#d9f99d" },
    claim: { displayName: "Claim", icon: <GiftOutlined />, disabled: false, isLoading: false, color: "#a5f3fc" },
  },
  sections: [
    {
      title: "Round Info",
      description: "All about this round.",
      content: mockData.roundInfo,
    },
    {
      title: "My Orders",
      description: "Input RoundID to search your order.",
      content: mockData.orderInfo,
    },
  ],
};
