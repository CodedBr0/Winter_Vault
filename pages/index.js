/* eslint-disable @next/next/no-img-element */
import {
  action,
  claimRewards,
  autoCompound,
  claimHolderRewards,
  formatMoney,
  getHolderDetails,
  getPoolDetails,
  switchChain,
  updateHolderRewards,
} from '@/utils/config';
import Head from 'next/head';
import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import StormCardSkeleton from '@/components/StormCardSkeleton';
import ConfettiExplosion from 'react-confetti-explosion';
import ActionButton from '@/components/ActionButton';
import HolderActionButton from '@/components/HolderActionButton';
import {
  useDisconnect,
  useWeb3Modal,
  useWeb3ModalAccount,
  useWeb3ModalEvents,
  useWeb3ModalProvider,
} from '@web3modal/ethers5/react';
import { STM_BUY_URL } from '@/utils/ConstantsUtil';
import dynamic from 'next/dynamic';
import { defaultChainId } from '@/utils/ConstantsUtil';
import { formatMoneyReadably } from '@/utils/config';
import CountUp from 'react-countup';

const SSRLessConnectionButton = dynamic(
  () => import('../components/ConnectionButton'),
  { ssr: false }
);

export default function Home() {
  const [poolInfo, setPoolInfo] = useState({});
  const [loading, setLoading] = useState(true);
  const [inputValue, setInputValue] = useState('');
  const [error, setError] = useState('');
  const [holderInfo, setHolderInfo] = useState({});
  const [infoIntervalId, setInfoIntervalId] = useState(null);
  const [isExploding, setIsExploding] = useState(false);
  const { address, chainId, isConnected } = useWeb3ModalAccount();
  const { open } = useWeb3Modal();
  const { walletProvider } = useWeb3ModalProvider();
  const events = useWeb3ModalEvents();
  const { disconnect } = useDisconnect();

  const largeConfetti = {
    force: 0.8,
    duration: 3000,
    particleCount: 300,
    width: 1600,
    colors: ['#041E43', '#1471BF', '#5BB4DC', '#FC027B', '#66D805'],
  };

  const handleChainChanged = useCallback((chainId) => {
    const newChainId = Number(chainId.toString());
    if (newChainId !== defaultChainId) {
      disconnectApp();
    }
  }, []);

  const getInterfaceInfo = useCallback(async () => {
    const id = setInterval(async () => {
      const fetchData = async () => {
        if (address) {
          try {
            const poolDetails = await getPoolDetails(walletProvider, address);
            const holderDetails = await getHolderDetails(
              walletProvider,
              address
            );
            setPoolInfo(poolDetails);
            setHolderInfo(holderDetails);
          } catch (err) {
            console.log(err);
          }
        }
      };

      await fetchData().then((_) => setLoading(false));
    }, 3000);

    setInfoIntervalId(id);
  }, [address, walletProvider]);

  const handleInputChange = (e) => {
    const value = e.target.value;
    if (value === '') {
      setError('Input is empty');
    } else if (Number(value) > poolInfo.userBalance) {
      setError('Insufficient balance');
    } else {
      setError('');
    }
    setInputValue(value);
  };

  const displayResult = (result) => {
    const resultDiv = document.querySelector('#result');
    resultDiv.innerHTML = result;
    resultDiv.style.display = 'block';

    setTimeout(() => {
      resultDiv.style.display = 'none';
    }, 5000);
  };

  const stake = async (setLoading, setDone, tokenAddress) => {
    const amount = inputValue;
    if (amount === 0 || amount === '') {
      setError('Amount cannot be empty');
      return;
    }
    setLoading(true);
    const result = await action(
      walletProvider,
      'stake',
      amount,
      tokenAddress
    ).then((value) => {
      setLoading(false);
      setDone(true);
      setTimeout(() => setDone(false), 5000);

      return value;
    });
    setInputValue('');

    if (result) {
      displayResult('Successfully staked!');
    }
  };

  const unstake = async (setLoading, setDone, tokenAddress) => {
    const amount = inputValue;
    if (amount === 0 || amount === '') {
      setError('Amount cannot be empty');
      return;
    }
    setLoading(true);
    const result = await action(
      walletProvider,
      'unstake',
      amount,
      tokenAddress
    ).then((value) => {
      setLoading(false);
      setDone(true);
      setTimeout(() => setDone(false), 5000);

      return value;
    });
    setInputValue('');

    if (result) {
      displayResult('Successfully unstaked!');
    }
  };

  const claimStakeRewards = async (setLoading, setDone, tokenAddress) => {
    setLoading(true);
    const result = await action(
      walletProvider,
      'unstake',
      '0',
      tokenAddress
    ).then((value) => {
      setLoading(false);
      setDone(true);
      setTimeout(() => setDone(false), 5000);

      return value;
    });

    if (result) {
      displayResult('Congratulations! You have claimed your rewards.');
    }
  };

  const compound = async (setLoading, setDone, _) => {
    setLoading(true);
    const result = await autoCompound(walletProvider).then((value) => {
      setLoading(false);
      setDone(true);
      setTimeout(() => setDone(false), 5000);

      return value;
    });

    if (result) {
      displayResult('Successfully auto-compounded!');
    }
  };

  const claimUnpaid = async (setLoading, setDone, _) => {
    setLoading(true);
    const result = await claimRewards(walletProvider).then((value) => {
      setLoading(false);
      setDone(true);
      setTimeout(() => setDone(false), 5000);

      return value;
    });

    if (result) {
      displayResult('Successfully claimed!');
    }
  };

  const disconnectApp = async () => {
    if (disconnect) {
      await disconnect();
    }
    setPoolInfo({ apy: poolInfo.apy });
    setHolderInfo({ apy: holderInfo.apy });
    clearInterval(infoIntervalId);
    setInputValue('');
    setError('');
    setInfoIntervalId(null);
    setLoading(false);
  };

  const updateHolder = async (e, setLoading, setDone) => {
    setLoading(true);
    e.target.disabled = true;

    try {
      await updateHolderRewards(walletProvider, address).then((_) => {
        setLoading(false);
        setDone(true);
        setTimeout(() => setDone(false), 5000);
      });
    } catch (err) {
      setLoading(false);
      console.log(err);
    } finally {
      e.target.disabled = false;
    }
  };

  const claimForHolder = async (e, setLoading, setDone) => {
    setLoading(true);
    e.target.disabled = true;

    try {
      await claimHolderRewards(walletProvider).then((_) => {
        setIsExploding(true);
        setLoading(false);
        setDone(true);

        setTimeout(() => setDone(false), 5000);
        setTimeout(() => setIsExploding(false), 3000);
      });
    } catch (err) {
      setLoading(false);
      console.log(err);
    } finally {
      e.target.disabled = false;
    }
  };

  const formatAddress = () => {
    return address
      ? `${address.slice(0, 5)}...${address.slice(-4)}`
      : '0x0...00';
  };

  useEffect(() => {
    if (window.ethereum) {
      window.ethereum.on('chainChanged', handleChainChanged);

      return () => {
        window.ethereum.removeListener('chainChanged', handleChainChanged);
      };
    }
  }, [handleChainChanged]); // <-- Add handleChainChanged here

  useEffect(() => {
    if (events.data.event === 'CONNECT_SUCCESS') {
      setLoading(true);
      getInterfaceInfo();
    }
  }, [events, getInterfaceInfo]); // <-- Add getInterfaceInfo here

  useEffect(() => {
    const switchToDefaultChain = async () => {
      if (isConnected && chainId != defaultChainId) {
        await switchChain(defaultChainId);
      }
    };

    switchToDefaultChain();
    if (isConnected && Object.keys(holderInfo).length < 2) {
      setLoading(true);
      getInterfaceInfo();
    } else {
      setLoading(false);
    }
  }, [isConnected, chainId, holderInfo, getInterfaceInfo]); // <-- Add holderInfo and getInterfaceInfo here

  return (
    <>
      <Head>
        <title>Storm Vault</title>
      </Head>

      <div id="wrapper" style={{ marginBottom: '4%' }}>
        {/* Navbar */}

        <div id="menu" className="our_nav">
          <div className="nav_inner">
            <nav className="storm-navbar">
              <div className="d-flex">
                <ul className="logo_container">
                  <li>
                    <div className="font_extrabold text_xl">
                      <Link href="https://winterstorm.finance">
                        <span className="logo">
                          <span className="logo_image">
                            <img src="logo_with_word.svg" alt="" />
                          </span>
                        </span>
                      </Link>
                    </div>
                  </li>
                </ul>
              </div>

              <span className="primary_links">
                <ul className="menu_right">
                  <li>
                    <a href="https://winterstorm.finance/#about">
                      about<span className="fillerTxt"></span>
                    </a>
                  </li>
                  <li>
                    <a href="https://winterstorm.finance/#tokenomics">
                      TOKENOMICS
                    </a>
                  </li>
                  <li>
                    <a href="https://winterstorm.finance/#roadmap">
                      ROAD MAP<span className="fillerTxt"></span>
                    </a>
                  </li>
                  <li>
                    <a href="https://winterstorm.finance/#community">
                      Community
                    </a>
                  </li>
                  <li>
                    <a href="https://docs.winterstorm.finance/" target="_blank">
                      WHITEPAPER
                    </a>
                  </li>
                </ul>
              </span>
            </nav>
            <div className="d-flex justify-content-around">
              <div className="d-flex align-items-center">
                <SSRLessConnectionButton
                  isConnected={isConnected}
                  openWeb3Modal={open}
                  tokenBalance={poolInfo?.userBalance}
                  disconnectApp={disconnectApp}
                  formatAddress={formatAddress}
                />
              </div>
              <div id="hamburger">
                <span></span>
                <span></span>
                <span></span>
                <span></span>
                <span>Menu</span>
              </div>
            </div>
          </div>
        </div>
        {/* Page Content */}
        <main className="content">
          <section className="roadmap">
            <div className="roadmap-title">
              <div className="con">
                <div className="desc">
                  <h2 className="pc">STORM STAKING POOL</h2>
                  <p className="p">
                    Staking of the people, by the people and for the people.
                  </p>
                </div>
              </div>
            </div>

            {loading ? (
              <StormCardSkeleton />
            ) : (
              <div className="column d-flex justify-content-center position-relative">
                <div className="storm_main">
                  <div className="storm_title d-flex align-items-center">
                    <img
                      className="mini-storm"
                      src="Storm_150x150.png"
                      alt=""
                    />
                    Stake STM to Earn STM
                  </div>
                  <div className="operate">
                    <div className="stake-info w-100">
                      <div className="d-flex justify-content-between">
                        <p>APY&nbsp;</p>
                        <p className="fw-bold">{poolInfo?.apy ?? 0}%</p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>Available $STM</p>
                        <p className="fw-bold">
                          <CountUp
                            end={poolInfo.userBalance ?? 0}
                            duration={2}
                            enableScrollSpy
                          />
                        </p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>My Stakings</p>
                        <p className="fw-bold">
                          <CountUp
                            end={poolInfo.userStakedAmount ?? 0}
                            duration={2}
                            enableScrollSpy
                          />
                        </p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>Pending Rewards</p>
                        <p className="fw-bold">{poolInfo.pendingReward ?? 0}</p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>Unpaid Rewards</p>
                        <p className="fw-bold">{poolInfo.unpaidRewards ?? 0}</p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>Total Staked</p>
                        <p className="fw-bold">
                          {formatMoney(poolInfo.totalAmountStaked ?? 0)}
                        </p>
                      </div>
                    </div>

                    <div className="storm_btns mt-3">
                      <button
                        className="btn btn-primary"
                        data-bs-toggle="modal"
                        data-bs-target="#stateModal">
                        Open Pool
                      </button>
                      <a
                        href={STM_BUY_URL}
                        className="btn btn-outline-primary text-primary"
                        style={{ background: 'transparent' }}
                        target="_blank">
                        GET STM
                      </a>
                    </div>
                  </div>

                  {/* STM/STM modal */}
                  <div
                    className="modal fade"
                    id="stateModal"
                    tabIndex="-1"
                    aria-labelledby="stateModalLabel"
                    aria-hidden="true">
                    <div className="modal-dialog modal-dialog-centered">
                      <div className="modal-content">
                        <div className="modal-header">
                          <div className="modal-title d-flex">
                            <h1 className="fs-5" id="stateModalLabel">
                              Stake <span className="fw-bold">STM</span>
                            </h1>
                          </div>
                          <button
                            type="button"
                            className="btn-close"
                            data-bs-dismiss="modal"
                            aria-label="Close"></button>
                        </div>
                        <div className="modal-body">
                          <div className="d-flex flex-column">
                            <div
                              className="alert alert-success p-2"
                              role="alert"
                              id="result"></div>
                            <div className="d-flex">
                              <input
                                type="number"
                                placeholder="0"
                                className={`form-control stake-amount w-100 ${
                                  error
                                    ? 'text-danger border border-danger'
                                    : ''
                                }`}
                                id="stakeAmount"
                                value={inputValue}
                                onChange={handleInputChange}
                              />
                            </div>
                            {error && (
                              <div className="text-danger">{error}</div>
                            )}

                            <div
                              className="d-flex justify-content-around my-3"
                              style={{ gap: '10px' }}>
                              <ActionButton
                                connected={isConnected}
                                action={stake}
                                text="Stake"
                                btnType="primary"
                              />

                              <ActionButton
                                connected={isConnected}
                                action={unstake}
                                text="Unstake"
                                btnType="primary"
                              />
                            </div>
                            <div
                              className="d-flex justify-content-around mb-1"
                              style={{ gap: '10px' }}>
                              <ActionButton
                                connected={isConnected}
                                action={claimStakeRewards}
                                text="Claim"
                                btnType="outline-primary"
                              />

                              {/*Track here*/}
                              <ActionButton
                                connected={isConnected}
                                action={claimUnpaid}
                                text="Claim Unpaid"
                                btnType="outline-primary"
                              />

                              <ActionButton
                                connected={isConnected}
                                action={compound}
                                text="Auto Compound"
                                btnType="outline-primary"
                              />
                            </div>
                          </div>
                        </div>
                        <div className="modal-footer d-flex justify-content-around text-center">
                          {/* Stake Info */}
                          <div className="d-flex flex-column">
                            <p>Your Stakings</p>
                            <p>{formatMoney(poolInfo.userStakedAmount ?? 0)}</p>
                          </div>
                          <div className="d-flex flex-column">
                            <p>Your Earnings</p>
                            <p>{formatMoney(poolInfo.pendingReward ?? 0)}</p>
                          </div>
                          <div className="d-flex flex-column">
                            <p>Wallet Balance</p>
                            <p>{formatMoney(poolInfo.userBalance ?? 0)}</p>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}

            <div className="roadmap-title">
              <div className="con">
                <div className="desc">
                  <h2 className="pc" style={{ marginTop: '100px' }}>
                    REWARD SYSTEM FOR HOLDERS
                  </h2>
                  <p className="p">Storm Holders reward panel.</p>
                </div>
              </div>
            </div>
            <div className="column d-flex justify-content-center">
              {loading ? (
                <StormCardSkeleton lineCount={4} />
              ) : (
                <div className="storm_main">
                  <div className="storm_title d-flex align-items-center">
                    <img
                      className="mini-storm"
                      src="Storm_150x150.png"
                      alt=""
                    />
                    Hold $STM to Earn $ETH
                  </div>
                  <div className="operate">
                    <div className="stake-info w-100">
                      <div className="d-flex justify-content-between">
                        <p>APY</p>
                        <p className="fw-bold">{holderInfo.apy ?? 0}%</p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>Pending Rewards</p>
                        <p className="fw-bold">
                          {holderInfo.pendingReward ?? 0} ETH
                        </p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>Last Updated Time</p>
                        <p className="fw-bold">
                          {holderInfo.lastUpdatedAt ?? '...'}
                        </p>
                      </div>
                      <div className="d-flex justify-content-between">
                        <p>$STM in Wallet</p>
                        <p className="fw-bold">
                          <CountUp
                            end={poolInfo.userBalance ?? 0}
                            duration={2}
                            enableScrollSpy
                          />{' '}
                          STM
                        </p>
                      </div>
                    </div>

                    <div className="storm_btns mt-3">
                      <HolderActionButton
                        connected={isConnected}
                        action={updateHolder}
                        className="btn btn-primary">
                        <span className="me-2">Update Reward</span>
                      </HolderActionButton>

                      <HolderActionButton
                        connected={isConnected}
                        action={claimForHolder}
                        className="btn btn-outline-primary d-flex justify-content-center align-items-center">
                        {isExploding && (
                          <ConfettiExplosion {...largeConfetti} />
                        )}
                        <span className="me-2">Claim Reward</span>
                      </HolderActionButton>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </section>
        </main>
      </div>
    </>
  );
}
