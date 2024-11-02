import Skeleton from 'react-loading-skeleton';

const StormCardSkeleton = ({ lineCount = 6 }) => {
  return (
    <div className="column d-flex justify-content-center position-relative">
      <div className="storm_main">
        <div className="storm_title d-flex align-items-center justify-content-center">
          <Skeleton circle width={48} height={44} />
          <h2 className="w-100 pb-0">
            <Skeleton />
          </h2>
        </div>
        <div className="operate">
          <div className="stake-info w-100">
            {Array(lineCount)
              .fill()
              .map((_, i) => (
                <Skeleton key={i} className="h-100" />
              ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default StormCardSkeleton;
