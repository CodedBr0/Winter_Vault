import tokenABI from '../abi/erc20abi.json';
import stormStakeABI from '../abi/stormStakeABI.json';
import holderBonusABI from '../abi/holderBonusABI.json';
import { ethers } from 'ethers';
import {
  stormStakeAddress,
  holderBonusAddress,
  tokenAddress,
} from './ConstantsUtil';
import numeral from 'numeral';

const convertToEth = async (type, value) => {
  switch (type) {
    case 'szabo':
      // Covert Szabo to ether
      return Number(ethers.utils.formatEther(value)).toFixed(8);
    case 'gether':
      // Convert from wei to gether
      return Number(ethers.utils.formatUnits(value, 27)).toFixed(2);
    default:
      // Convert from Wei to ether
      return Number(ethers.utils.formatEther(value));
  }
};

const convertToWei = async (value) => {
  return ethers.utils.parseEther(value);
};

export async function connectWallet(walletProvider) {
  const provider = new ethers.providers.Web3Provider(walletProvider);
  const signer = provider.getSigner();
  const stormStakeContract = new ethers.Contract(
    stormStakeAddress,
    stormStakeABI,
    signer
  );
  const holderContract = new ethers.Contract(
    holderBonusAddress,
    holderBonusABI,
    signer
  );

  return { signer, stormStakeContract, holderContract };
}

export const fetchTokenBalance = async (signer, userWalletAddress) => {
  const tokenContract = new ethers.Contract(tokenAddress, tokenABI, signer);
  const poolBalance = await tokenContract.balanceOf(stormStakeAddress);
  const pool = await convertToEth(null, poolBalance);
  const userBalance = await tokenContract.balanceOf(userWalletAddress);
  const user = await convertToEth(null, userBalance);

  return { pool, user };
};

export const getPoolDetails = async (walletProvider, address) => {
  const { signer, stormStakeContract } = await connectWallet(walletProvider);
  const apy = Number((await stormStakeContract?.APY()).toString());
  const userStakingInfo = await stormStakeContract?.getUserView(address);
  const userStakedAmount = Number(
    await convertToEth(null, userStakingInfo[0].toString())
  ).toFixed(2);
  const pendingReward = Number(
    await convertToEth(null, userStakingInfo[1].toString())
  ).toFixed(2);
  const unpaidRewards = Number(
    await convertToEth(null, userStakingInfo[2].toString())
  ).toFixed(2);
  const totalStakedRaw = await stormStakeContract?.totalStaked();
  const totalAmountStaked = Number(
    await convertToEth(null, totalStakedRaw.toString())
  ).toFixed(2);
  const tokenBalances = await fetchTokenBalance(signer, address);
  const userBalance = tokenBalances.user.toFixed(2);

  const poolStats = {
    apy,
    userStakedAmount,
    pendingReward,
    totalAmountStaked,
    userBalance,
    unpaidRewards,
  };

  return poolStats;
};

export const action = async (walletProvider, action, amount, tokenAddress) => {
  try {
    const amountToWei = (await convertToWei(amount)).toString();
    const { stormStakeContract, signer } = await connectWallet(walletProvider);
    if (action === 'unstake') {
      const result = await stormStakeContract
        ?.unstake(amountToWei)
        .then((_) => true);
      return result;
    } else {
      const tokenContract = new ethers.Contract(tokenAddress, tokenABI, signer);
      const approveTransfer = await tokenContract.approve(
        stormStakeAddress,
        amountToWei
      );
      const waitApproval = approveTransfer.wait();
      if (waitApproval) {
        const result = await stormStakeContract
          ?.stake(amountToWei)
          .then((_) => true);
        return result;
      }
    }
  } catch (err) {
    console.log(err);
  }
};

export const autoCompound = async (walletProvider) => {
  const { stormStakeContract } = await connectWallet(walletProvider);

  try {
    const result = await stormStakeContract?.autoCompound().then((_) => true);
    return result;
  } catch (err) {
    console.log(err);
  }
};

export const claimRewards = async (walletProvider) => {
  const { stormStakeContract } = await connectWallet(walletProvider);

  try {
    const result = await stormStakeContract?.claimRewards().then((_) => true);
    return result;
  } catch (err) {
    console.log(err);
  }
};

export const getHolderDetails = async (walletProvider, address) => {
  const { holderContract } = await connectWallet(walletProvider);

  const holderInfo = await holderContract?.getUserView(address);

  const userInfos = await holderContract?.userInfos(address);
  const lastUpdateTimeInUnix = Number(userInfos[1].toString());
  const lastUpdateTimestamp = new Date(lastUpdateTimeInUnix * 1000);
  const formattedlastUpdateDate = `${lastUpdateTimestamp.toLocaleDateString(
    'en-US',
    { weekday: 'short', month: 'short', day: 'numeric' }
  )} at ${lastUpdateTimestamp.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: 'numeric',
  })}`;

  const holderStats = {
    tokenBalance: Number(
      await convertToEth(null, holderInfo[0].toString())
    ).toFixed('2'),
    pendingReward: Number(
      await convertToEth(null, holderInfo[1].toString())
    ).toFixed('4'),
    apy: Number(holderInfo[2].toString()),
    lastUpdatedAt: formattedlastUpdateDate,
  };

  return holderStats;
};

export const switchChain = async (targetChainId) => {
  let result = false;

  try {
    await window.ethereum
      .request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${targetChainId.toString(16)}` }],
      })
      .then(() => (result = true));

    return result;
  } catch (switchError) {
    // This error code indicates that the chain has not been added.
    if (switchError.code === 4902) {
      try {
        await window.ethereum
          .request({
            method: 'wallet_addEthereumChain',
            params: [
              {
                chainId: `0x${targetChainId.toString(16)}`,
              },
            ],
          })
          .then(() => (result = true));

        return result;
      } catch (addError) {
        console.log(addError);

        return result;
      }
    } else {
      return result;
    }
  }
};

export const updateHolderRewards = async (walletProvider, address) => {
  const { holderContract } = await connectWallet(walletProvider);

  return await holderContract?.updateReward().then((_) => true);
};

export const claimHolderRewards = async (walletProvider) => {
  const { holderContract } = await connectWallet(walletProvider);

  return await holderContract?.claimReward().then((_) => true);
};

export const formatMoneyReadably = (number) => {
  return numeral(number).format('0.0a').toUpperCase();
};

export const formatMoney = (number) => {
  return numeral(number).format('0,0.00');
};
