using HexIO;
using System.Drawing;
using System.Text;

namespace Untitled_Assembler
{
	internal class Program
	{
		static void Main(string[] args)
		{
			string? inputFilePath = null;
			string? outputFilePath = null;

			string? inputFileName = null;

			string? outputFileFormat = "bin";

			int minOutputFileSize = 0;
			
			for (int i = 0; i < args.Length; i++)
			{
				string currArg = args[i];
				
				bool lastTwoArgFlag = i >= args.Length - 1;
				switch (currArg)
				{
					case "-i":
						if (!lastTwoArgFlag)
						{
							inputFilePath = args[++i];
							inputFileName = Path.GetFileNameWithoutExtension(inputFilePath);
						}
						break;
					case "-o":
						if (!lastTwoArgFlag)
						{
							outputFilePath = args[++i];
							outputFileFormat = Path.GetExtension(outputFilePath).TrimStart('.');
						}
						break;
					case "-f":
						if (!lastTwoArgFlag)
							outputFileFormat = args[++i].TrimStart('.');
						break;
					case "-s":
						if (!lastTwoArgFlag)
							int.TryParse(args[++i], out minOutputFileSize);
						break;

				}
			}

			if (inputFilePath != null)
			{
				Assembler assembler = new Assembler();

				string assemblyCode = File.ReadAllText(inputFilePath);

				assembler.Compile(assemblyCode, minOutputFileSize);

				if (assembler.hasError)
				{
					Console.WriteLine(assembler.errors);
				}
				else
				{
					Console.WriteLine("Compile succeed.");

					if (outputFilePath == null)
					{
						outputFilePath = Path.GetFileNameWithoutExtension(inputFilePath) + '.' + outputFileFormat;
					}

					FileStream fileStream = new FileStream(outputFilePath, FileMode.Create);

					if (fileStream != null)
					{
						int i;
						switch (outputFileFormat)
						{
							case "bin":
								fileStream.Write(assembler.outputBytes, 0, assembler.outputBytes.Length);
								break;
							case "hex":
								if (assembler.outputByteList != null)
								{
									IntelHexStreamWriter writer = new IntelHexStreamWriter(fileStream, Encoding.UTF8);

									i = 0;
									while (i < assembler.outputByteList.Count)
									{
										writer.WriteDataRecord((ushort)i, assembler.outputByteList.GetRange(i, Math.Min(i + 255, assembler.outputByteList.Count - 1)));
										i += 255;
									}

									writer.Close();
								}
								break;
							case "mi":
								StreamWriter streamWriter = new StreamWriter(fileStream);
								
								string headerStr = "#File_format=AddrHex\n" +
									"#Address_depth=" + assembler.outputBytes.Length + '\n' +
									"#Data_width=8";

								//Console.WriteLine(headerStr);
								streamWriter.WriteLine(headerStr);

								i = 0;
								while (i < assembler.outputBytes.Length)
								{
									string currentLine = i.ToString("X") + ":" + assembler.outputBytes[i].ToString("X2");
									//Console.WriteLine(currentLine);
									streamWriter.WriteLine(currentLine);

									i++;
								}

								streamWriter.Close();
								break;
							default:
								Console.WriteLine("Invaild file format " + outputFileFormat);
								break;
						}

						fileStream.Close();
					}
					else
					{
						Console.WriteLine("Failed to create output file.");
					}
				}
			}
			else
			{
				Console.WriteLine("Input file is not specificed.");
			}
		}
	}
}
