// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


module.exports = buildModule("PikaPay", (m) => {
 
  const usdtAddress = m.getParameter("usdtAddress","0x48db5c1155836dE945fB82b6A9CF82D91AC21f16");
  const pikaPay = m.contract("PikaPay", [usdtAddress]);
  return { pikaPay};
 
});


// usdt : 0x48db5c1155836dE945fB82b6A9CF82D91AC21f16