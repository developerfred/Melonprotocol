import { withNewAccount } from '~/utils/environment/withNewAccount';
import { createQuantity } from '@melonproject/token-math';
import { sendEth } from '~/utils/evm/sendEth';
import { setupInvestedTestFund } from '../utils/setupInvestedTestFund';

import { deposit } from '~/contracts/dependencies/token/transactions/deposit';
import { getTokenBySymbol } from '~/utils/environment/getTokenBySymbol';
import { toBeTrueWith } from '../utils/toBeTrueWith';
import { getSystemTestEnvironment } from '../utils/getSystemTestEnvironment';
import { Tracks } from '~/utils/environment/Environment';
import { createOrder } from '~/contracts/exchanges/third-party/0x/utils/createOrder';
import { signOrder } from '~/contracts/exchanges/third-party/0x/utils/signOrder';
// import { makeEthfinexOrder } from '~/contracts/fund/trading/transactions/makeEthfinexOrder';
import { setEthfinexWrapperRegistry } from '~/contracts/version/transactions/setEthfinexWrapperRegistry';
import { getWrapperLock } from '~/contracts/exchanges/third-party/ethfinex/calls/getWrapperLock';

expect.extend({ toBeTrueWith });

// const getLog = getLogCurried('melon:protocol:systemTest:playground');

describe('playground', () => {
  test('Happy path', async () => {
    const master = await getSystemTestEnvironment(Tracks.KYBER_PRICE);

    const manager = await withNewAccount(master);
    const weth = getTokenBySymbol(master, 'WETH');
    const mln = getTokenBySymbol(master, 'MLN');
    const wrapperRegistryEFX = '0x750DeaE872619eb2Cf6c65FD07FCbc60E8D98b73';
    const wethWrapperLock = await getWrapperLock(master, wrapperRegistryEFX, {
      token: weth,
    });

    await sendEth(master, {
      howMuch: createQuantity('ETH', 3),
      to: manager.wallet.address,
    });

    const quantity = createQuantity(weth, 2);

    await deposit(manager, quantity.token.address, undefined, {
      value: quantity.quantity.toString(),
    });

    const routes = await setupInvestedTestFund(manager);

    // const ethfinex =
    //   manager.deployment.exchangeConfigs[Exchanges.Ethfinex].exchange;

    const ethfinex = '0x35dd2932454449b14cee11a94d3674a936d5d7b2';

    await setEthfinexWrapperRegistry(
      master,
      manager.deployment.melonContracts.registry,
      {
        address: wrapperRegistryEFX,
      },
    );
    // const howMuch = createQuantity(weth, 1);

    // console.log('asdasdasd');
    // const receipt = await transfer(manager, {
    //   howMuch,
    //   to: routes.vaultAddress,
    // });
    // console.log('asdasdasd');

    // expect(receipt).toBeTruthy();

    const makerQuantity = createQuantity(wethWrapperLock, 0.05);
    const takerQuantity = createQuantity(mln, 1);

    const unsignedEthfinexOrder = await createOrder(manager, ethfinex, {
      makerAddress: routes.tradingAddress,
      makerQuantity,
      takerQuantity,
    });
    const signedOrder = await signOrder(manager, unsignedEthfinexOrder);
    console.log(signedOrder);
  });
});
