﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Xml.Linq;
using Microsoft.Practices.Unity;
using VidCoder.Model;
using VidCoder.Properties;
using VidCoder.ViewModel;
using VidCoder.ViewModel.Components;

namespace VidCoder.Services
{
	public class PresetImportExport : IPresetImportExport
	{
		private IFileService fileService;
		private IMessageBoxService messageBoxService;
		private PresetsViewModel presetsViewModel = Unity.Container.Resolve<PresetsViewModel>();

		public PresetImportExport(IFileService fileService, IMessageBoxService messageBoxService)
		{
			this.fileService = fileService;
			this.messageBoxService = messageBoxService;
		}

		public void ImportPreset(string presetFile)
		{
			Preset preset = Presets.LoadPresetFile(presetFile);
			if (preset == null || string.IsNullOrWhiteSpace(preset.Name))
			{
				this.messageBoxService.Show("Could not import preset. Format is unrecognized.", "Import Error", System.Windows.MessageBoxButton.OK);
				return;
			}

			preset.IsBuiltIn = false;
			preset.IsModified = false;

			List<Preset> existingPresets = Presets.UserPresets;
			if (existingPresets.Count(existingPreset => existingPreset.Name == preset.Name) > 0)
			{
				string proposedName;

				for (int i = 2; i < 100; i++)
				{
					proposedName = preset.Name + " (" + i + ")";
					if (existingPresets.Count(existingPreset => existingPreset.Name == proposedName) == 0)
					{
						preset.Name = proposedName;
						break;
					}
				}
			}

			this.messageBoxService.Show("Successfully imported preset " + preset.Name + ".", "Success", System.Windows.MessageBoxButton.OK);

			this.presetsViewModel.AddPreset(preset);
		}

		public void ExportPreset(Preset preset)
		{
			var exportPreset = new Preset
			    {
					EncodingProfile = preset.EncodingProfile.Clone(),
					IsBuiltIn = false,
					IsModified = false,
					IsQueue = false,
					Name = preset.Name
			    };

			string initialFileName = exportPreset.Name;
			if (preset.IsModified)
			{
				initialFileName += "_Modified";
			}

			string exportFileName = this.fileService.GetFileNameSave(
				Settings.Default.LastPresetExportFolder,
				"Export preset",
				Utilities.CleanFileName(initialFileName + ".xml"),
				"xml",
				"XML Files|*.xml");
			if (exportFileName != null)
			{
				Settings.Default.LastPresetExportFolder = Path.GetDirectoryName(exportFileName);
				Settings.Default.Save();

				if (Presets.SavePresetToFile(exportPreset, exportFileName))
				{
					this.messageBoxService.Show(
						"Successfully exported preset to " + exportFileName,
						"Success",
						System.Windows.MessageBoxButton.OK);
				}
			}
		}
	}
}
