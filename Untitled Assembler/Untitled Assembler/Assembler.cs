using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Untitled_Assembler
{
	internal class Assembler
	{
		struct Label
		{
			public string label;
			public int addr;
			public int addrType;
			public string fromLine;

			public Label(string newLabel, int newAddr, int newType = 0, string from = "")
			{
				label = newLabel;
				addr = newAddr;

				// For operations
				//	0 - Absolute
				//	1 - H8
				//	2 - L8
				//	3 - Relative
				//	4 - NULL
				addrType = newType;

				fromLine = from;
			}
		};

		List<List<string>>? operations;
		List<Label>? labels;
		List<Label>? operWithLabel;

		public bool hasError = false;
		public string errors = "";

		public List<byte>? outputByteList;
		public byte[] outputBytes = new byte[] { };

		string OperationToString(List<string> operation)
		{
			if (operation.Count >= 1)
			{
				string output = "";

				for (int i = 1; i < operation.Count; i++)
				{
					if (i > 1)
						output += ' ';

					output += operation[i].ToUpper();
				}

				return output;
			}
			else
				return "";
		}

		void AddError(List<string> operation, string? detail = null)
		{
			hasError = true;
			errors += $"Error at line {operation[0]} : {OperationToString(operation)}";
			if (detail != null)
				errors += " : " + detail;

			errors += ".\n";
		}

		void AppendAddr(List<string> operation, ref int addr, bool relative = false)
		{
			int address = 0;
			if (!int.TryParse(operation[2].TrimStart('$').TrimEnd('h'), System.Globalization.NumberStyles.HexNumber, null, out address))
			{
				if (operWithLabel != null)
					operWithLabel.Add(new Label(operation[2].TrimStart('$'), addr + 1, relative ? 3 : 0, operation[0]));

				addr += 2;
			}
			else
			{
				if (address < 0 || address > 65535)
				{
					AddError(operation, "invalid address range");
					address = address > 65535 ? 65535 : address < 0 ? 0 : address;
				}

				if (outputByteList != null)
				{
					// ADDR_H
					ChangeByte(addr++, (byte)((address >> 8) & 0xFF));
					// ADDR_L
					ChangeByte(addr++, (byte)(address & 0xFF));
				}
			}
		}

		void AppendBranch(List<string> operation, byte opcodeDirect, byte opcodeIndirect, ref int addr)
		{
			if (operation.Count == 3)
			{
				string para = operation[2];

				if (para.StartsWith('$'))
				{
					// LDA $addr
					ChangeByte(addr++, opcodeDirect);

					AppendAddr(operation, ref addr, true);
				}
				else if (para.StartsWith("(a"))
				{
					// LDA (An)
					para = para.Substring(2).TrimEnd(')');

					int addrRegSelection = 0;
					if (!int.TryParse(para, out addrRegSelection))
					{
						AddError(operation, "invalid address register");
					}

					if (addrRegSelection > 3 || addrRegSelection < 0)
					{
						AddError(operation, "invalid address register");
						addrRegSelection = addrRegSelection > 3 ? 3 : addrRegSelection < 0 ? 0 : addrRegSelection;
					}

					ChangeByte(addr++, (byte)(opcodeIndirect + addrRegSelection));
				}
			}
			else
			{
				AddError(operation, "invalid parameter");
			}
		}

		void AppendTransfer(List<string> operation, byte opcode, ref int addr)
		{
			if (operation.Count == 3)
			{
				string para = operation[2];

				int regSelection = 0;
				switch (para)
				{
					case "a0l":
						regSelection = 8;
						break;
					case "a0h":
						regSelection = 9;
						break;
					case "a1l":
						regSelection = 10;
						break;
					case "a1h":
						regSelection = 11;
						break;
					case "a2l":
						regSelection = 12;
						break;
					case "a2h":
						regSelection = 13;
						break;
					case "a3l":
						regSelection = 14;
						break;
					case "a3h":
						regSelection = 15;
						break;
					default:
						if (!int.TryParse(para.TrimStart('r'), System.Globalization.NumberStyles.HexNumber, null, out regSelection))
						{
							AddError(operation, "invalid register number");
						}
						break;
				}

				if (regSelection > 15 || regSelection < 0)
				{
					AddError(operation, "invalid register number");
					regSelection = regSelection > 15 ? 15 : regSelection < 0 ? 0 : regSelection;
				}

				ChangeByte(addr++, (byte)(opcode + regSelection));
			}
			else
			{
				AddError(operation, "invalid parameter");
			}
		}

		void ChangeByte(int addr, byte value)
		{
			if (outputByteList != null)
			{
				while (outputByteList.Count <= addr)
				{
					outputByteList.Add(0x00);
				}

				outputByteList[addr] = value;
			}
		}

		Label FindLabel(string labelName)
		{
			if (labels != null)
			{
				foreach (Label label in labels)
				{
					if (labelName == label.label)
						return label;
				}
			}

			return new Label("", 0, 4);
		}

		public bool Compile(string assemblyCode, int minSize = 0)
		{
			operations = new List<List<string>>();
			labels = new List<Label>();
			operWithLabel = new List<Label>();

			List<string> eachLine = assemblyCode.Split(new string[] {"\r", "\r\n", "\n"}, StringSplitOptions.RemoveEmptyEntries).ToList();
			for (int i = 0; i < eachLine.Count; i++)
			{
				string currLine = eachLine[i];

				List<string> operation = currLine.Split(new char[] { }, StringSplitOptions.RemoveEmptyEntries).ToList();
				if (operation.Count > 0)
				{
					bool hasString = false;
					if (operation[0].StartsWith(".db"))
					{
						int start = -1;
						int end = -1;
						int j = 0;
						while (j < currLine.Length)
						{
							if (currLine[j] == '"')
							{
								if (start == -1)
									start = j;
								else if (end == -1)
								{
									if (j > 0)
									{
										if (currLine[j - 1] != '\\')
										{
											end = j;
											break;
										}
									}
								}
							}

							j++;
						}

						if (start >= 0 && end >= 0)
						{
							hasString = true;
							operation = new List<string> { ".db", '"' + currLine.Substring(start, end - start + 1) + '"' };
						}

						operation.Insert(0, (i + 1).ToString());

						operations.Add(operation);
					}
					else if (!operation[0].StartsWith(';'))
					{
						int j = 0;
						while (j < operation.Count)
						{
							if (operation[j].StartsWith(';'))
							{
								operation.RemoveRange(j, operation.Count - j);
							}
							j++;
						}

						operation.Insert(0, (i + 1).ToString());

						operations.Add(operation);
					}

					if (!hasString)
						for (int j = 0; j < operations[operations.Count - 1].Count; j++)
							operations[operations.Count - 1][j] = operations[operations.Count - 1][j].ToLower();
				}
			}

			int addr = 0;

			outputByteList = new List<byte>();
			hasError = false;
			errors = "";
			for (int i = 0; i < operations.Count; i++)
			{
				List<string> currOper = operations[i];
				if (currOper.Count > 1)
				{
					switch (currOper[1])
					{
						case "nop":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b00000000);
							else
								AddError(currOper, "invalid parameter");
							break;
						// LOAD / STORE
						case "lda":
							if (currOper.Count == 3)
							{
								string para = currOper[2];

								if (para.StartsWith('#'))
								{
									// LDA #imm
									ChangeByte(addr++, 0b00001010);

									if (para.EndsWith(".h"))
									{
										string label = para.TrimStart('#');
										label = label.Substring(0, label.Length - 2);
										operWithLabel.Add(new Label(label, addr++, 1, currOper[0]));
									}
									else if (para.EndsWith(".l"))
									{
										string label = para.TrimStart('#');
										label = label.Substring(0, label.Length - 2);
										operWithLabel.Add(new Label(label, addr++, 2, currOper[0]));
									}
									else
									{
										int immNum = 0;
										if (!int.TryParse(para.TrimStart('#').TrimEnd('h'), System.Globalization.NumberStyles.HexNumber, null, out immNum))
										{
											AddError(currOper, "invalid immediate number");
										}

										if (immNum > 255 || immNum < 0)
										{
											AddError(currOper, "invalid number range");
											immNum = immNum > 255 ? 255 : immNum < 0 ? 0 : immNum;
										}

										ChangeByte(addr++, (byte)immNum);
									}
								}
								else if (para.StartsWith('$'))
								{
									// LDA $addr
									ChangeByte(addr++, 0b00001001);

									AppendAddr(currOper, ref addr);
								}
								else if (para.StartsWith("(a"))
								{
									// LDA (An)
									para = para.Substring(2).TrimEnd(')');

									int addrRegSelection = 0;
									if (!int.TryParse(para, out addrRegSelection))
									{
										AddError(currOper, "invalid address register");
									}

									if (addrRegSelection > 3 || addrRegSelection < 0)
									{
										AddError(currOper, "invalid address register");
										addrRegSelection = addrRegSelection > 3 ? 3 : addrRegSelection < 0 ? 0 : addrRegSelection;
									}

									ChangeByte(addr++, (byte)(0b00000100 + addrRegSelection));
								}
								else
								{
									AddError(currOper, "invalid parameter");
								}
							}
							else
							{
								AddError(currOper, "invalid parameter");
							}
							break;
						case "sta":
							if (currOper.Count == 3)
							{
								string para = currOper[2];

								if (para.StartsWith('$'))
								{
									// STA $addr
									ChangeByte(addr++, 0b00001011);

									AppendAddr(currOper, ref addr);
								}
								else if (para.StartsWith("(a"))
								{
									// STA (An)
									para = para.Substring(2).TrimEnd(')');

									int addrRegSelection = 0;
									if (!int.TryParse(para, out addrRegSelection))
									{
										AddError(currOper, "invalid address register");
									}

									if (addrRegSelection > 3 || addrRegSelection < 0)
									{
										AddError(currOper, "invalid address register");
										addrRegSelection = addrRegSelection > 3 ? 3 : addrRegSelection < 0 ? 0 : addrRegSelection;
									}

									ChangeByte(addr++, (byte)(0b00001100 + addrRegSelection));
								}
								else
								{
									AddError(currOper, "invalid parameter");
								}
							}
							else
							{
								AddError(currOper, "invalid parameter");
							}
							break;
						// TRANSFER
						case "tab":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b00001000);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "trb":
							AppendTransfer(currOper, 0b00010000, ref addr);
							break;
						case "tar":
							AppendTransfer(currOper, 0b00110000, ref addr);
							break;
						case "tra":
							AppendTransfer(currOper, 0b00100000, ref addr);
							break;
						// ARITHMETIC / LOGIC
						case "add":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000000);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "sub":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000001);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "and":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000010);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "ora":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000011);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "not":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000110);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "eor":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000111);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "lsl":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000100);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "lsr":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01000101);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "rol":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01001000);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "ror":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01001001);
							else
								AddError(currOper, "invalid parameter");
							break;
						// COMPARISON / BRANCHING
						case "cmp":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01010000);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "bra":
							AppendBranch(currOper, 0b01010001, 0b01010100, ref addr);
							break;
						case "beq":
							AppendBranch(currOper, 0b01010011, 0b01011100, ref addr);
							break;
						case "blt":
							AppendBranch(currOper, 0b01010010, 0b01011000, ref addr);
							break;
						// STACK / SUBROUTINE
						case "ssp":
							if (currOper.Count == 3)
							{
								string para = currOper[2];

								if (para.StartsWith('$'))
								{
									// LDA $addr
									ChangeByte(addr++, 0b01100000);

									AppendAddr(currOper, ref addr);
								}
								else
								{
									AddError(currOper, "invalid parameter");
								}
							}
							else
							{
								AddError(currOper, "invalid parameter");
							}
							break;
						case "puh":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01100001);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "pop":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01100011);
							else
								AddError(currOper, "invalid parameter");
							break;
						case "bsr":
							AppendBranch(currOper, 0b01100010, 0b01100100, ref addr);
							break;
						case "ret":
							if (currOper.Count == 2)
								ChangeByte(addr++, 0b01101000);
							else
								AddError(currOper, "invalid parameter");
							break;
						// RESERVED
						case ".org":
							if (currOper.Count == 3)
							{
								int address = 0;
								if (!int.TryParse(currOper[2].TrimStart('$').TrimEnd('h'), System.Globalization.NumberStyles.HexNumber, null, out address))
								{
									AddError(currOper, "parameter is not a valid hex number");
								}

								if (address < 0 || address > 65535)
								{
									AddError(currOper, "invalid address range");
									address = address > 65535 ? 65535 : address < 0 ? 0 : address;
								}

								addr = address;
							}
							else
								AddError(currOper, "invalid parameter");
							break;
						case ".db":
							if (currOper.Count == 3)
							{
								string para = currOper[2];

								if (para.StartsWith('#'))
								{
									if (para.EndsWith(".h"))
									{
										string label = para.TrimStart('#');
										label = label.Substring(0, label.Length - 2);
										operWithLabel.Add(new Label(label, addr++, 1, currOper[0]));
									}
									else if (para.EndsWith(".l"))
									{
										string label = para.TrimStart('#');
										label = label.Substring(0, label.Length - 2);
										operWithLabel.Add(new Label(label, addr++, 2, currOper[0]));
									}
									else
									{
										int immNum = 0;
										if (!int.TryParse(para.TrimStart('#').TrimEnd('h'), System.Globalization.NumberStyles.HexNumber, null, out immNum))
										{
											AddError(currOper, "invalid immediate number");
										}

										if (immNum > 255 || immNum < 0)
										{
											AddError(currOper, "invalid number range");
											immNum = immNum > 255 ? 255 : immNum < 0 ? 0 : immNum;
										}

										ChangeByte(addr++, (byte)immNum);
									}
								}
								else if (para.StartsWith('$'))
								{
									AppendAddr(currOper, ref addr);
								}
								else if (para.StartsWith('"') && para.EndsWith('"'))
								{
									byte[] strToAppend = Encoding.ASCII.GetBytes(para.Trim('"') + '\0');
									for (int j = 0; j < strToAppend.Length; j ++)
									{
										ChangeByte(addr++, strToAppend[j]);
									}
								}
								else
								{
									AddError(currOper, "invalid parameter");
								}
							}
							else
							{
								AddError(currOper, "invalid parameter");
							}
							break;
						default:
							if (currOper[1].EndsWith(':'))
							{
								labels.Add(new Label(currOper[1].TrimEnd(':'), addr));
							}
							else
								AddError(currOper, "invalid operation");
							break;
					}
				}
			}

			foreach (Label labelInOper in operWithLabel)
			{
				Label label = FindLabel(labelInOper.label);
				switch (labelInOper.addrType)
				{
					case 0:
						// ABSOLUTE
						ChangeByte(labelInOper.addr - 1, (byte)((label.addr >> 8) & 0xFF));
						ChangeByte(labelInOper.addr, (byte)(label.addr & 0xFF));
						break;
					case 1:
						// H8
						ChangeByte(labelInOper.addr, (byte)((label.addr >> 8) & 0xFF));
						break;
					case 2:
						// L8
						ChangeByte(labelInOper.addr, (byte)(label.addr & 0xFF));
						break;
					case 3:
						// RELATIVE
						int addrRelative = label.addr - labelInOper.addr;
						if (addrRelative >= 65536)
							addrRelative -= 65536;
						else if (addrRelative < 0)
							addrRelative += 65536;

						ChangeByte(labelInOper.addr - 1, (byte)((addrRelative >> 8) & 0xFF));
						ChangeByte(labelInOper.addr, (byte)(addrRelative & 0xFF));
						break;
					case 4:
						AddError(new List<string> { labelInOper.fromLine, labelInOper.label }, "label cannot found");
						break;
				}
			}

			while (outputByteList.Count < minSize)
			{
				outputByteList.Add(0x00);
			}

			if (!hasError)
			{
				outputBytes = outputByteList.ToArray();
			}

			return !hasError;
		}
	}
}
