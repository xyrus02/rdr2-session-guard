using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace XyrusWorx.Gaming.GtaV.SessionGuard.Input 
{
	public static class HotKeyManager
	{
		[DllImport("user32", SetLastError = true)]
		private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

		[DllImport("user32", SetLastError = true)]
		private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
		
		private static int mId;
		private static volatile MessageWindow mWindow;
		private static volatile IntPtr mHwnd;
		private static readonly ManualResetEvent mWindowReadyEvent = new ManualResetEvent(false);

		private delegate void RegisterHotKeyDelegate(IntPtr hwnd, int id, uint modifiers, uint key);
		private delegate void UnRegisterHotKeyDelegate(IntPtr hwnd, int id);
		
		static HotKeyManager()
		{
			var messageLoop = new Thread(() => System.Windows.Forms.Application.Run(new MessageWindow()));
			messageLoop.Name = "MessageLoopThread";
			messageLoop.IsBackground = true;
			messageLoop.Start();
		}
		
		public static event EventHandler<HotKeyEventArgs> HotKeyPressed;

		public static int RegisterHotKey(Keys key, KeyModifiers modifiers)
		{
			mWindowReadyEvent.WaitOne();
			var id = Interlocked.Increment(ref mId);
			mWindow.Invoke(new RegisterHotKeyDelegate(RegisterHotKeyInternal), mHwnd, id, (uint)modifiers, (uint)key);
			return id;
		}
		public static void UnregisterHotKey(int id)
		{
			mWindow.Invoke(new UnRegisterHotKeyDelegate(UnRegisterHotKeyInternal), mHwnd, id);
		}

		private static void RegisterHotKeyInternal(IntPtr hwnd, int id, uint modifiers, uint key)
		{
			RegisterHotKey(hwnd, id, modifiers, key);
		}
		private static void UnRegisterHotKeyInternal(IntPtr hwnd, int id)
		{
			UnregisterHotKey(mHwnd, id);
		}

		private static void OnHotKeyPressed(HotKeyEventArgs e)
		{
			if (HotKeyManager.HotKeyPressed != null)
			{
				HotKeyManager.HotKeyPressed(null, e);
			}
		}

		class MessageWindow : Form
		{
			private const int mWmHotkey = 0x312;
			
			public MessageWindow()
			{
				mWindow = this;
				mHwnd = Handle;
				mWindowReadyEvent.Set();
			}

			protected override void WndProc(ref Message m)
			{
				if (m.Msg == mWmHotkey)
				{
					var e = new HotKeyEventArgs(m.LParam);
					OnHotKeyPressed(e);
				}

				base.WndProc(ref m);
			}
			protected override void SetVisibleCore(bool value)
			{
				base.SetVisibleCore(false);
			}
		}
	}
}