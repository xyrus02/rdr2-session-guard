using System;
using System.Windows.Forms;

namespace XyrusWorx.Gaming.Rdr2.SessionGuard.Input 
{
	public class HotKeyEventArgs : EventArgs
	{
		internal HotKeyEventArgs(IntPtr hotKeyParam)
		{
			var param = (uint)hotKeyParam.ToInt64();
			Key = (Keys)((param & 0xffff0000) >> 16);
			Modifiers = (KeyModifiers)(param & 0x0000ffff);
		}
		
		public Keys Key { get; }
		public KeyModifiers Modifiers { get; }
	}
}