import { useState } from 'react';

const HolderActionButton = ({ connected, action, className, children }) => {
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);

  return (
    <button
      className={className}
      onClick={(e) => action(e, setLoading, setDone)}
      disabled={!connected}>
      {children}

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

export default HolderActionButton;
