const DENOMINATOR_LOG_16 = Math.log(16);

function timeDifferenceToStepSize(diff: number) {
  return diff < 256
    ? 16
    : 16 ** Math.floor(Math.log(diff) / DENOMINATOR_LOG_16);
}

/**
 * Returns the nearest valid time from the given input time and the current block time
 * @param now the current block time
 * @param time the time to find the nearest usable time from
 * @param roundUp whether to round to the future valid time or past valid time
 */
function toNearestValidTime({
  blockTime,
  time,
  roundUp,
}: {
  blockTime: number;
  time: number;
  roundUp?: boolean;
}): number {
  if (roundUp === undefined) {
    const down = toNearestValidTime({
      blockTime,
      time,
      roundUp: false,
    });
    const up = toNearestValidTime({
      blockTime,
      time,
      roundUp: true,
    });
    if (Math.abs(down - time) <= Math.abs(up - time)) {
      return down;
    } else {
      return up;
    }
  }

  const diff = time - blockTime;

  if (diff < 256) {
    return roundUp ? Math.ceil(time / 16) * 16 : Math.floor(time / 16) * 16;
  }

  const stepSize = timeDifferenceToStepSize(diff);

  const mod = time % stepSize;

  // already aligned
  if (mod === 0) {
    return time;
  }

  if (roundUp) {
    // step size can get bigger, so the current time rounded to the next step size may be invalid
    const next = time + (stepSize - mod);
    return toNearestValidTime({
      blockTime,
      time: next,
      roundUp: true,
    });
  } else {
    // step size can get smaller, so the current time rounded down to the next step size may not be the closest valid time
    const next = time - mod;
    const stepSizePrev = timeDifferenceToStepSize(next - blockTime);
    if (stepSizePrev === stepSize) {
      return next;
    }
    return Math.floor(
      Math.floor((blockTime + stepSize - 1) / stepSizePrev) * stepSizePrev
    );
  }
}

if (require.main === module) {
    const [, , blockTimeArg, timeArg, roundUpArg] = process.argv;
    const blockTime = parseInt(blockTimeArg, 10);
    const time = parseInt(timeArg, 10);
    const roundUp = roundUpArg === 'true';
  
    if (isNaN(blockTime) || isNaN(time)) {
      console.error('Usage: ts-node twammTimestamps.ts <blockTime> <time> [roundUp]');
      process.exit(1);
    }
  
    const result = toNearestValidTime({ blockTime, time, roundUp });
    console.log('Nearest valid time:', result);
  }