#!/usr/bin/env python3
import yaml
import re
import sys
from collections import OrderedDict

# Necessary to dump OrderedDict to yaml format
yaml.add_representer(OrderedDict, lambda dumper, data: dumper.represent_mapping('tag:yaml.org,2002:map', data.items()))

verbose = False

if len(sys.argv) > 1:
  field_table_name = sys.argv[1]
else:
  field_table_name = 'field_table'
if verbose:
  print(field_table_name)

class Field:
  def __init__(self, in_field_type, entry_tuple):
    self.field_type = in_field_type
    self.name = entry_tuple[0]
    self.dict = OrderedDict()
    for in_prop in entry_tuple[1]:
      if 'tracer' == self.field_type:
        self.process_tracer(in_prop)
      else:
        self.process_species(in_prop)

  def process_species(self, prop):
    comma_split = prop.split(',')
    if verbose:
      print(self.name)
      print(self.field_type)
      print(comma_split)
    if len(comma_split) > 1:
      eq_splits = [x.split('=') for x in comma_split]
      if verbose:
        print(eq_splits)
      for idx, sub_param in enumerate(eq_splits):
        if verbose:
          print(len(sub_param))
        if len(sub_param) < 2:
          eq_splits[0][1] += f',{sub_param[0]}'
          if verbose:
            print(eq_splits)
      eq_splits = [eq_splits[0]]
      for sub_param in eq_splits:
        if ',' in sub_param[1]:
          val = [yaml.safe_load(b) for b in sub_param[1].split(',')]
        else:
          val = yaml.safe_load(sub_param[1])
        self.dict[sub_param[0]] = val
    else:
      eq_split = comma_split[0].split('=')
      val = yaml.safe_load(eq_split[1])
      self.dict[eq_split[0]] = val
    
  def process_tracer(self, prop):
    if verbose:
      print(len(prop))
    if len(prop) < 3:
      self.dict[prop[0]] = prop[1]
    else:
      self.dict[prop[0]] = OrderedDict()
      self.dict[prop[0]]['value'] = prop[1]
      if verbose:
        print(self.name)
        print(self.field_type)
        print(prop[2:])
      for sub_param in prop[2:]:
        eq_split = sub_param.split('=')
        val = yaml.safe_load(eq_split[-1])
        if isinstance(val, list):
          val = [yaml.safe_load(b) for b in val]
        self.dict[prop[0]][eq_split[0]] = val
      
out_yaml = OrderedDict()

if __name__ == '__main__':
  with open(field_table_name, 'r') as fh:
    whole_file = fh.read()
  # Eliminate spaces, tabs, and quotes
  whole_file = whole_file.replace(' ', '').replace('"', '').replace('\t', '')
  # Eliminate anything after a comment marker (#)
  whole_file = re.sub("\#"+r'.*'+"\n",'\n',whole_file)
  # Eliminate trailing commas (rude)
  whole_file = whole_file.replace(',\n', '\n')
  # Split entries based upon the "/" ending character
  into_lines = [x for x in re.split("/\s*\n", whole_file) if x]
  # Eliminate blank lines
  into_lines = [re.sub(r'\n+','\n',x) for x in into_lines]
  into_lines = [x[1:] if '\n' in x[:1] else x for x in into_lines]
  into_lines = [x[:-1] if '\n' in x[-1:] else x for x in into_lines]
  # Split already split entries along newlines to form nested list
  nested_lines = [x.split('\n') for x in into_lines]
  # Split nested lines into "heads" (field_type, model, var_name) and "tails" (the rest)
  heads = [x[0] for x in nested_lines]
  tails = [x[1:] for x in nested_lines]
  # Get unique combination of field_type and model... in order provided
  ordered_keys = OrderedDict.fromkeys([tuple([y.lower() for y in x.split(',')[:2]]) for x in heads])
  # Initialize lists
  for k in ordered_keys.keys():
    ordered_keys[k] = []
    if k[0] not in out_yaml.keys():
      out_yaml[k[0]] = OrderedDict()
    if k[1] not in out_yaml[k[0]].keys():
      out_yaml[k[0]][k[1]] = OrderedDict()
  # Populate entries as OrderedDicts
  for h, t in zip(heads, tails):
    head_list = [y.lower() for y in h.split(',')]
    tail_list = [x.split(',') for x in t]
    if (head_list[0], head_list[1]) in ordered_keys.keys():
      if 'tracer' == head_list[0]:
        ordered_keys[(head_list[0], head_list[1])].append((head_list[2], tail_list))
      else:
        ordered_keys[(head_list[0], head_list[1])].append((head_list[2], t))
  # Make Tracer and Species objects and assign to out_yaml
  for k in ordered_keys.keys():
    for j in ordered_keys[k]:
      my_entry = Field(k[0], j)
      out_yaml[k[0]][k[1]][my_entry.name] = my_entry.dict
  # Make out_yaml file
  with open(f'{field_table_name}.yaml', 'w') as yaml_file:
    yaml.dump(out_yaml, yaml_file, default_flow_style=False)
