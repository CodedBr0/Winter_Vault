import { useState } from 'react';
import { tokenAddress } from '@/utils/ConstantsUtil';

const ActionButton = ({ connected, action, text, btnType }) => {
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);

  return (
    <button
      className={`btn btn-${btnType} w-100 d-flex justify-content-center align-items-center`}
      onClick={() => action(setLoading, setDone, tokenAddress)}
      disabled={!connected}>
      <span className="me-2">{text}</span>

      {loading && <i className="fa-solid fa-rotate fa-spin"></i>}
      {done && !loading && (
        <i
          className="fa-solid fa-circle-check"
          style={{
            animation: 'zoomOut 5s forwards',
          }}></i>
      )}
    </button>
  );
};

export default ActionButton;
