﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace VidCoder.ViewModel
{
	using Resources;

	public class AboutDialogViewModel : OkCancelDialogViewModel
	{
		public string Version
		{
			get
			{
				return Utilities.VersionString;
			}
		}

		public string BasedOnHandBrake
		{
			get
			{
				//return string.Format(MiscRes.BasedOnHandBrakeStable, "0.9.9");
				return string.Format(MiscRes.BasedOnHandBrake, 5776);
			}
		}

		public string Copyright
		{
			get
			{
				return string.Format(MiscRes.Copyright, "2010-2013");
			}
		}
	}
}
