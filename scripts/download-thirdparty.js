const rp = require('request-promise');
const fs = require('fs');
const thirdpartyDir = './thirdparty';

const baseUrl = 'https://raw.githubusercontent.com/melonproject/thirdparty-artifacts';
const commitHash = '1413a3c64a5c649bff01c1275f6acc5ad092a5c5';

// per-project mapping of actual contract names to the names we use
const artifacts = {
  kyber: {
    'ConversionRates': 'ConversionRates',
    'ExpectedRate': 'ExpectedRate',
    'FeeBurner': 'FeeBurner',
    'KyberNetwork': 'KyberNetwork',
    'KyberNetworkProxy': 'KyberNetworkProxy',
    'KyberReserve': 'KyberReserve',
    'WhiteList': 'KyberWhiteList',
  },
  oasis: {
    'MatchingMarket': 'OasisDexExchange',
  },
  zeroExV2: {
    'ERC20Proxy': 'ZeroExV2ERC20Proxy',
    'Exchange': 'ZeroExV2Exchange',
  },
  zeroExV3: {
    'Exchange': 'ZeroExV3Exchange',
    'Staking': 'ZeroExV3Staking',
    'StakingProxy': 'ZeroExV3StakingProxy',
    'ZrxVault': 'ZeroExV3ZrxVault'
  },
  airSwap: {
    'Swap': 'AirSwapSwap',
    'Types': 'AirSwapTypes',
    'ERC20TransferHandler': 'AirSwapERC20TransferHandler',
    'TransferHandlerRegistry': 'AirSwapTransferHandlerRegistry'
  },
  uniswap: {
    'UniswapExchange': 'UniswapExchange',
    'UniswapFactory': 'UniswapFactory'
  }
}

const mkdir = dir => !fs.existsSync(dir) && fs.mkdirSync(dir);

const request = (projectName, contractName) => {
  const options =  {
    uri: `${baseUrl}/${commitHash}/artifacts/${projectName}/${contractName}.json`
  }
  return rp(options);
};

const wrapRequest = async (
  request,
  projectName,
  originalContractName,
  outputContractName
) => {
  return {
    projectName,
    outputContractName,
    content: (await request(projectName, originalContractName))
  };
}

(async () => {
  const requests = Object.entries(artifacts)
    .map(([projectName, contractNameMappings]) => (
      Object.entries(contractNameMappings).map(
        ([originalName, outputName]) => wrapRequest(
          request, projectName, originalName, outputName
        )
      )
    )
  ).reduce((a,b) => a.concat(b), []);

  try {
    mkdir(thirdpartyDir);
    const results = await Promise.all(requests);
    for (const result of results) {
      const { outputContractName, content } = result;

      fs.writeFileSync(`${thirdpartyDir}/${outputContractName}.json`, content);
    }
  }
  catch (e) {
    console.error(e)
  }
})();
