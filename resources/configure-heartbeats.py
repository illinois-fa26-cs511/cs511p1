#!/usr/bin/env python3
"""Set fast heartbeat timing for the small MP1 cluster before HDFS starts."""
import os
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET


def main():
    hdfs = shutil.which('hdfs')
    if hdfs is None:
        return  # Part 0: students have not installed Hadoop yet.
    home = Path(os.environ.get('HADOOP_HOME') or Path(hdfs).resolve().parent.parent)
    conf = Path(os.environ.get('HADOOP_CONF_DIR') or home / 'etc/hadoop')
    path = conf / 'hdfs-site.xml'
    tree = ET.parse(path) if path.exists() else ET.ElementTree(ET.Element('configuration'))
    root = tree.getroot()
    if root.tag != 'configuration':
        raise ValueError('Expected <configuration> in %s' % path)
    values = {'dfs.heartbeat.interval': '1',
              'dfs.namenode.heartbeat.recheck-interval': '1000'}
    for name, value in values.items():
        matches = [p for p in root.findall('property') if p.findtext('name') == name]
        for prop in matches:
            root.remove(prop)
        prop = ET.SubElement(root, 'property')
        ET.SubElement(prop, 'name').text = name
        ET.SubElement(prop, 'value').text = value
    conf.mkdir(parents=True, exist_ok=True)
    tree.write(path, encoding='utf-8', xml_declaration=True)
    print('MP1 HDFS heartbeat: 1s; NameNode recheck: 1000ms (%s)' % path)


if __name__ == '__main__':
    main()
