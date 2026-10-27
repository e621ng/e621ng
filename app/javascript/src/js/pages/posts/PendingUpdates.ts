import ToastManager, { Toast } from "@/utility/Toast";

/** The shared "Updating posts (N pending)..." toast for index-style bulk actions. */
export default class PendingUpdates {

  private static toast: Toast | null = null;
  private static _count = 0;

  static get count (): number { return PendingUpdates._count; }

  static begin (): void {
    PendingUpdates.ensureToast();
    PendingUpdates._count += 1;
    PendingUpdates.toast.message = `Updating posts (${PendingUpdates._count} pending)...`;
  }

  static end (): void {
    PendingUpdates.ensureToast();
    PendingUpdates._count -= 1;

    if (PendingUpdates._count < 1) {
      PendingUpdates._count = 0;
      PendingUpdates.toast.message = "Posts updated";
      PendingUpdates.toast.timeout = 3;
      PendingUpdates.toast = null;
    } else {
      PendingUpdates.toast.message = `Updating posts (${PendingUpdates._count} pending)...`;
    }
  }

  /** Counts the operation as pending until the promise settles. The settlement passes through. */
  static track<T> (promise: Promise<T>): Promise<T> {
    PendingUpdates.begin();
    return promise.finally(() => PendingUpdates.end());
  }

  private static ensureToast (): void {
    if (!PendingUpdates.toast) PendingUpdates.toast = ToastManager.create("Updating posts...", { timeout: 0 });
    ToastManager.dismiss("Posts updated");
  }
}
