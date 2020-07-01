const mainnetAddrs = require('../config');
const Registry = artifacts.require('Registry');
const WETH = artifacts.require('WETH');
const MLN = artifacts.require('MLN');

module.exports = async (deployer, _, [admin]) => {
  await deployer.deploy(Registry, admin);

  const registry = await Registry.deployed();
  await registry.setMGM(mainnetAddrs.melon.MelonInitialMGM);

  const weth = await WETH.at(mainnetAddrs.tokens.WETH);
  const mln = await MLN.at(mainnetAddrs.tokens.MLN);
  await registry.setNativeAsset(weth.address);
  await registry.setMlnToken(mln.address);
}
