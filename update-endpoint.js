import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';

const __dirname = dirname(fileURLToPath(import.meta.url));

// 使用 yargs 解析命令行参数
const argv = await yargs(hideBin(process.argv))
  .usage('$0 [options]', '更新 config.json 中的 Cloudflare WARP endpoint 地址')
  .option('v4', {
    alias: 'endpoint-v4',
    type: 'string',
    description: 'IPv4 endpoint 地址',
    demandOption: true,
  })
  .option('v6', {
    alias: 'endpoint-v6',
    type: 'string',
    description: 'IPv6 endpoint 地址',
    demandOption: true,
  })
  .option('config', {
    alias: 'c',
    type: 'string',
    description: '配置文件路径',
    default: join(__dirname, 'config.json'),
  })
  .example('$0 --v4 162.159.199.2 --v6 2606:4700:103::2', '更新 endpoint 地址')
  .example('$0 -v4 162.159.192.2 -v6 2606:4700:100::2', '使用短选项')
  .help('help', '显示帮助信息')
  .alias('help', 'h')
  .version('version', '显示版本号', '1.0.0')
  .alias('version', 'v')
  .wrap(100)
  .strict()
  .argv;

// 读取配置文件
try {
  const configContent = readFileSync(argv.config, 'utf8');
  const config = JSON.parse(configContent);

  // 显示当前值
  console.log('当前配置:');
  console.log(`  endpoint_v4: ${config.endpoint_v4}`);
  console.log(`  endpoint_v6: ${config.endpoint_v6}`);

  // 更新值
  config.endpoint_v4 = argv.v4;
  config.endpoint_v6 = argv.v6;

  // 写回文件（保持格式化）
  writeFileSync(argv.config, JSON.stringify(config, null, 2) + '\n', 'utf8');

  console.log('\n✓ 配置已更新:');
  console.log(`  endpoint_v4: ${config.endpoint_v4}`);
  console.log(`  endpoint_v6: ${config.endpoint_v6}`);

} catch (error) {
  console.error('错误:', error.message);
  process.exit(1);
}
