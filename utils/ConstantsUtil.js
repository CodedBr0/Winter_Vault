export const stormStakeAddress = '0xf2248F32f468cDa48d40E3524872658Cef40F909';

export const holderBonusAddress = '0x8607fe48758A0dd3F86d6839c4AB126242EE4Bb5';

export const tokenAddress = '0x7e0ae5fc38c8E55D05d6281b96A55b8d88A6756E';

export const STM_BUY_URL = '';

const mainnetChainId = 8453;

const testnetChainId = 84532;

export const defaultChainId = testnetChainId;

// Chains
const mainnet = {
  chainId: mainnetChainId,
  name: 'Base',
  currency: 'ETH',
  explorerUrl: 'https://basescan.org',
  rpcUrl: 'https://mainnet.base.org',
};

const testnet = {
  chainId: testnetChainId,
  name: 'Base Sepolia',
  currency: 'ETH',
  explorerUrl: 'https://sepolia.basescan.org',
  rpcUrl: 'https://sepolia.base.org',
};

export const defaultNet = testnet;
