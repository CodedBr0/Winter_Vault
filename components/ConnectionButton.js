import { STM_BUY_URL } from '@/utils/ConstantsUtil';
import { formatMoneyReadably } from '@/utils/config';
import Image from 'next/image';

const ConnectionButton = ({
  isConnected,
  openWeb3Modal,
  tokenBalance,
  disconnectApp,
  formatAddress,
}) => {
  return (
    <div className="mi-dropdown">
      <button
        className="mi-dropbtn d-flex align-items-center connect-btn"
        onClick={() => !isConnected && openWeb3Modal()}>
        {isConnected ? <>{formatAddress()} &nbsp;</> : 'Connect Wallet'}

        {isConnected && (
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            fill="#fff"
            className="bi bi-chevron-down connectArrow"
            viewBox="0 0 16 16">
            <path
              fillRule="evenodd"
              d="M1.646 4.646a.5.5 0 0 1 .708 0L8 10.293l5.646-5.647a.5.5 0 0 1 .708.708l-6 6a.5.5 0 0 1-.708 0l-6-6a.5.5 0 0 1 0-.708z"
            />
          </svg>
        )}
      </button>

      {isConnected && (
        <div className="mi-dropdown-content">
          <div className="d-flex justify-content-center align-items-center flex-column">
            <Image className="mini-storm" src="/Storm_150x150.png" alt="" width={150} height={150} />
            <p>{formatMoneyReadably(tokenBalance)} STM</p>
          </div>
          <a
            href={STM_BUY_URL}
            className="btn btn-info w-100"
            style={{ borderRadius: '12px', fontSize: '14px' }}
            target="_blank">
            Buy STM
          </a>
          <button
            className="btn btn-primary w-100"
            style={{ borderRadius: '12px', fontSize: '14px' }}
            onClick={disconnectApp}>
            Disconnect
          </button>
        </div>
      )}
    </div>
  );
};

export default ConnectionButton;
