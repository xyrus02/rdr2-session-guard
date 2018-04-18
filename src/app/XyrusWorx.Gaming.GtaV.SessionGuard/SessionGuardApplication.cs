using System;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using NetFwTypeLib;
using XyrusWorx.Gaming.GtaV.SessionGuard.Input;
using XyrusWorx.Runtime;
using XyrusWorx.Threading;

namespace XyrusWorx.Gaming.GtaV.SessionGuard
{
	class SessionGuardApplication : ConsoleApplication
	{
		private int mScrollLockHotkey;
		private int mPauseHotkey;

		private bool mIsSessionLocked;
		private Process mGtaProcess;

		[DllImport("user32.dll")]
		private static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vk);

		[DllImport("user32.dll")]
		private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
		
		[DllImport("kernel32.dll")]
		private static extern IntPtr OpenThread(int dwDesiredAccess, bool bInheritHandle, uint dwThreadId);
		
		[DllImport("kernel32.dll")]
		private static extern uint SuspendThread(IntPtr hThread);
		
		[DllImport("kernel32.dll")]
		private static extern int ResumeThread(IntPtr hThread);
		
		[DllImport("kernel32", CharSet = CharSet.Auto, SetLastError = true)]
		private static extern bool CloseHandle(IntPtr handle);

		protected override IResult InitializeOverride()
		{
			mScrollLockHotkey = HotKeyManager.RegisterHotKey(Keys.Scroll, KeyModifiers.Shift);
			mPauseHotkey = HotKeyManager.RegisterHotKey(Keys.Pause, KeyModifiers.Shift);

			HotKeyManager.HotKeyPressed += OnHotkeyPressed;

			return Result.Success;
		}
		protected override void CleanupOverride()
		{
			HotKeyManager.HotKeyPressed -= OnHotkeyPressed;
			
			HotKeyManager.UnregisterHotKey(mScrollLockHotkey);
			HotKeyManager.UnregisterHotKey(mPauseHotkey);
		}

		protected override IResult Execute(CancellationToken cancellationToken)
		{
			Log.Write("Hooks ready. Your hotkey are:");
			Log.Write("   [SHIFT + SCRLK] => Lock / unlock session");
			Log.Write("   [SHIFT + PAUSE] => Clean session");

			var ctr = 0;
			
			Console.WriteLine();
			
			Log.Write("Waiting for GTA V...");
			DetectGtaProcess();
			
			while (!cancellationToken.IsCancellationRequested)
			{
				if (Console.KeyAvailable)
				{
					var key = Console.ReadKey();
					if (key.Key == ConsoleKey.Escape)
					{
						break;
					}
				}

				Thread.Sleep(100);
				ctr++;

				if (ctr > 0 && ctr % 20 == 0)
				{
					DetectGtaProcess();
					ctr = 0;
				}
			}

			return Result.Success;
		}

		private void DetectGtaProcess()
		{
			if (mGtaProcess != null)
			{
				return;
			}
			
			mGtaProcess = GetGtaProcess();

			if (mGtaProcess != null)
			{
				Log.Write($"Process found! PID: {mGtaProcess.Id}");
				mGtaProcess.EnableRaisingEvents = true;
				mGtaProcess.Exited += OnGtaProcessExit;
			}
		}
		private Process GetGtaProcess() => Process.GetProcessesByName("GTA5").FirstOrDefault();
		
		private void ToggleSessionLock()
		{
			const string clsFwPolicy2 = "{E2B3C97F-6AE1-41AC-817A-F6F92166D7DD}";
			const string clsFwRule = "{2C5BC43E-3369-4C33-AB0C-BE9469677AF4}";

			const string ruleName = @"GTA_V_SESSION_LOCK";
			
			var typeFwPolicy2 = Type.GetTypeFromCLSID(new Guid(clsFwPolicy2));
			var typeFwRule = Type.GetTypeFromCLSID(new Guid(clsFwRule));

			var fwPolicy2 = (INetFwPolicy2)Activator.CreateInstance(typeFwPolicy2);
			
			if (!mIsSessionLocked)
			{
				((INetFwRule)Activator.CreateInstance(typeFwRule)).TryConsume(
					rule =>
					{
						rule.Name = ruleName;
						
						rule.Protocol = (int)NET_FW_IP_PROTOCOL_.NET_FW_IP_PROTOCOL_UDP;
						rule.Direction = NET_FW_RULE_DIRECTION_.NET_FW_RULE_DIR_OUT;
						rule.Action = NET_FW_ACTION_.NET_FW_ACTION_BLOCK;
						
						rule.Description = "GTA V Session Lock";
						rule.LocalPorts = "6672,61455,61457,61456,61458";
						rule.Grouping = "@firewallapi.dll,-23255";
						
						rule.Enabled = true;

						fwPolicy2.Rules.Add(rule);
					});
				
				Log.Write("Session is now LOCKED");
			}
			else
			{
				fwPolicy2.Rules.Remove(ruleName);
				Log.Write("Session is now UNLOCKED");
			}
			
			mIsSessionLocked = !mIsSessionLocked;
		}
		private void CleanSession()
		{
			const int suspendResume = 0x0002;
			var op = new RelayOperation(
				() =>
				{
					if (mGtaProcess == null)
					{
						return;
					}
					
					foreach (ProcessThread thread in mGtaProcess.Threads)
					{
						var threadHandle = IntPtr.Zero;
						try
						{
							threadHandle = OpenThread(suspendResume, false, (uint)thread.Id);
							if (threadHandle == IntPtr.Zero)
							{
								continue;
							}
							
							SuspendThread(threadHandle);
						}
						finally
						{
							if (threadHandle != IntPtr.Zero)
							{
								CloseHandle(threadHandle);
							}
						}
					}

					Console.Write("Cleaning session");
					
					for (var i = 0; i < 10; i++)
					{
						Console.Write(".");
						Thread.Sleep(TimeSpan.FromSeconds(1));
					}
					
					Console.WriteLine();
					
					foreach (ProcessThread thread in mGtaProcess.Threads)
					{
						var threadHandle = IntPtr.Zero;
						try
						{
							threadHandle = OpenThread(suspendResume, false, (uint)thread.Id);
							if (threadHandle == IntPtr.Zero)
							{
								continue;
							}
							
							int suspendCount;
							do
							{
								suspendCount = ResumeThread(threadHandle);
							} 
							while (suspendCount > 0);
						}
						finally
						{
							if (threadHandle != IntPtr.Zero)
							{
								CloseHandle(threadHandle);
							}
						}
					}
					
					Log.Write("Session should be clean!");
				});
			
			op.DispatchMode = OperationDispatchMode.BackgroundThread;
			op.Run();
		}
		
		private void OnGtaProcessExit(object sender, EventArgs e)
		{
			Log.Write("Process terminated. Waiting for restart...");
			mGtaProcess = null;
		}
		private void OnHotkeyPressed(object sender, HotKeyEventArgs e)
		{
			if (!e.Modifiers.HasFlag(KeyModifiers.Shift))
			{
				return;
			}
			
			switch (e.Key)
			{
				case Keys.Scroll:
					ToggleSessionLock();
					break;
				case Keys.Pause:
					CleanSession();
					break;
			}
		}

		static void Main(string[] args) => new SessionGuardApplication().Run();
	}

}
