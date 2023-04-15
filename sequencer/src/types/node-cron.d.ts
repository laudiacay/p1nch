declare module 'node-cron' {
  export function schedule(
    cronExpression: string,
    callback: () => void,
    options?: {
      scheduled?: boolean;
      timezone?: string;
    }
  ): {
    start: () => void;
    stop: () => void;
  };
}
