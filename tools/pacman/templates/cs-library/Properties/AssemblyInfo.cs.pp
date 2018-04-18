using System.Reflection;

[assembly: AssemblyTitle("[[ $_.EffectiveConfiguration.getProperty("Title") ]]")]
[assembly: AssemblyProduct("[[ $_.EffectiveConfiguration.getProperty("Product") ]]")]
[assembly: AssemblyDescription("[[ $_.EffectiveConfiguration.getProperty("Description") ]]")]
[assembly: AssemblyCompany("[[ $_.EffectiveConfiguration.getProperty("Company") ]]")]
[assembly: AssemblyCopyright("Copyright (C) [[ (get-date).year ]] [[ $_.EffectiveConfiguration.getProperty("Company") ]]")]