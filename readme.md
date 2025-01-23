This project contains bash scripts to modify files including json and plain text.

### insert_lines.sh
Usage: ./insert_lines.sh <file> <line_number> <'before'|'after'> <text_to_insert>"<br>

```bash
Example: ./insert_lines.sh myfile.txt 3 before \
  'Inserted line 1\r Inserted line 2\r'
````

### json_replace.sh
Perform search and replace. Target files are treated as plain text.

#### Examples

##### Simple field value replacement.
```bash
./json_replace.sh -t target/sample.json -p "..inner.name" -v "new value"
```

##### Replace the value of a fully qualified field in a file with a simple text value.
``` bash
./json_replace.sh -t directory/file.json \ 
-f '.properties.policyRule.then.details.deployment.properties.template.resources[1].properties.template.resources[0].properties.criteria.allOf[0].query' \
-v 'new-value-goes-here'
```

##### Replace the value of a fully qualified field in a file with an KQL query formatted for bash.
```bash
set +H # disable history expansion
./json_replace.sh -t directory/file.json \
  -f '.properties.policyRule.then.details.deployment.properties.template.resources[1].properties.template.resources[0].properties.criteria.allOf[0].query' \
  -v '"[[format('let policyThresholdString = \"{2}\"; let excludedResources = (arg(\"\").resources | where type =~ \"Microsoft.Compute/virtualMachines\" | project _ResourceId = id, tags | where parse_json(tostring(tags.[\"{0}\"])) in~ (\"{1}\")); let excludedVMSSNodes = (arg(\"\").resources | where type =~ \"Microsoft.Compute/virtualMachines\" | extend isVMSS = isnotempty(properties.virtualMachineScaleSet) | where isVMSS | project id, name); let overridenResource = (arg(\"\").resources | where type =~ \"Microsoft.Compute/virtualMachines\" | project _ResourceId = tolower(id), tags | where tags contains \"_amba-ReadLatencyMs-Data-threshold-Override_\"); InsightsMetrics | where _ResourceId has \"Microsoft.Compute/virtualMachines\" | where _ResourceId !in~ (excludedResources) | where _ResourceId !in~ (excludedVMSSNodes) | where Origin == \"vm.azm.ms\" | where Namespace == \"LogicalDisk\" and Name == \"ReadLatencyMs\" | extend Disk=tostring(todynamic(Tags)[\"vm.azm.ms/mountId\"]) | where Disk !in (\"C:\", \"/\") | summarize AggregatedValue = avg(Val) by bin(TimeGenerated, 15m), Computer, _ResourceId, Disk | join hint.remote=left kind=leftouter overridenResource on _ResourceId | project-away _ResourceId1 | extend appliedThresholdString = iif(tags contains \"_amba-ReadLatencyMs-Data-threshold-Override_\", tostring(tags.[\"_amba-ReadLatencyMs-Data-threshold-Override_\"]), policyThresholdString) | extend appliedThreshold = toint(appliedThresholdString) | where AggregatedValue > appliedThreshold | project TimeGenerated, Computer, _ResourceId, Disk, AggregatedValue', parameters('MonitorDisableTagName'), join(parameters('MonitorDisableTagValues'), '\",\"'), parameters('threshold'))]"

set -H # enable history expansion
```

### search_replace.sh
Usage: $0 -s <search_text> -r <replace_text> [-f <file_path>] [-d <directory_path>]<br/>
Options:
- -s    Text to search for
- -r    Text to replace with
- -f    Target a specific file
- -d    Target a directory (recursively processes all files)

Note: Either -f or -d must be provided, but not both.


