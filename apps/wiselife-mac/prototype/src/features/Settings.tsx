import { useEffect, useRef, useState } from "react";
import { Archive, Cpu, Folder, FolderOpen, Video } from "lucide-react";
import { Alert, Button, Heading, Input, Modal, Panel, Tag } from "../components/ui";
const initialPath = "~/Documents/EurekaLife";
export function useDirectory(notify: (text: string) => void) {
  const [path, setPath] = useState(initialPath);
  const [draft, setDraft] = useState(initialPath);
  const [opened, setOpened] = useState(false);
  const [moving, setMoving] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(timer.current), []);
  const clean = draft.trim().replace(/\/+$/, "");
  const valid = (clean.startsWith("/") || clean.startsWith("~/")) && clean.length > 2 && !clean.split("/").includes("..") && !/[\n\r\0]/.test(clean);
  function change() {
    if (!valid || clean === path || moving) return;
    setMoving(true);
    timer.current = setTimeout(() => {
      setPath(clean); setMoving(false); setOpened(false);
      notify("主目录已更新（演示），模型、会议与每日备份位置同步更新");
    }, 1100);
  }
  function reset() { clearTimeout(timer.current); setPath(initialPath); setDraft(initialPath); setOpened(false); setMoving(false); }
  return { path, draft, setDraft, opened, setOpened, moving, valid, clean, change, reset };
}
export type DirectoryModel = ReturnType<typeof useDirectory>;
export function DirectorySettings({ directory: d, blocked }: { directory: DirectoryModel; blocked: boolean }) {
  return <>
    <Heading title="主目录设置" description="为模型和记录，留一个统一的家。" />
    {blocked && <Alert status="waiting" title="请先结束录制、整理、下载或备份，再更改主目录。" classNames={{ message: "whitespace-normal" }} />}
    <Panel>
      <div className="flex flex-wrap items-start justify-between gap-[20px]">
        <div className="flex min-w-0 gap-[16px]">
          <FolderOpen size={24} className="shrink-0 text-[#595959]" />
          <div className="min-w-0"><h2 className="mb-[10px] text-[16px] font-medium">EurekaLife 主目录</h2>
            <p data-testid="root-path" className="m-0 break-all text-[14px] leading-[1.8]">{d.path}</p>
            <p className="mb-0 mt-[8px] text-[12px] text-[#8c8c8c]">模型、会议文件和每日备份统一存放在这里。</p>
          </div>
        </div>
        <Button variant="outline" onClick={() => { d.setDraft(d.path); d.setOpened(true); }} disabled={d.moving || blocked}>更改主目录</Button>
      </div>
    </Panel>
    <div className="mt-[8px]"><h2 className="text-[16px] font-medium">目录内容</h2><p className="text-[13px] leading-[1.8] text-[#8c8c8c]">各类资料独立整理，随主目录一起管理。</p></div>
    <div className="flex flex-col gap-[12px]">
      {[
        { name: "模型库", folder: "Models", description: "语言模型、语音转写与说话人模型", Icon: Cpu },
        { name: "会议文件", folder: "Meetings", description: "录音、视频、原文、总结与对话", Icon: Video },
        { name: "每日记录", folder: "DailyRecords", description: "按设备和日期保存 EurekaLife App 的每日备份", Icon: Archive },
      ].map(({ name, folder, description, Icon }) => <Panel key={folder}><div className="flex gap-[16px]">
        <Icon size={20} className="shrink-0 text-[#8c8c8c]" /><div className="min-w-0 flex-1">
          <h3 className="mb-[6px] text-[14px] font-medium">{name}</h3><p className="mb-[8px] text-[13px] leading-[1.7] text-[#8c8c8c]">{description}</p>
          <p className="m-0 break-all text-[12px] text-[#595959]">{d.path}/{folder}</p>
        </div><Folder size={16} className="shrink-0 text-[#bfbfbf]" /></div></Panel>)}
    </div>
    <p className="text-[12px] leading-[1.8] text-[#8c8c8c]">更改时一并迁移现有资料；完成后再切换主目录。此原型只演示路径和迁移状态，不会操作磁盘。</p>
  </>;
}
export function DirectoryDialog({ directory: d }: { directory: DirectoryModel }) {
  return <Modal opened={d.opened} onClose={() => { if (!d.moving) d.setOpened(false); }} title="更改主目录" closeOnEscape={!d.moving} closeOnClickOutside={!d.moving} withCloseButton={!d.moving} size={560}>
    <div className="flex flex-col gap-[20px]">
      <p className="m-0 text-[14px] leading-[1.8] text-[#595959]">模型、会议文件、每日备份将一起移动到新位置。迁移期间暂停下载、录制与备份。</p>
      <Input label="新的主目录" value={d.draft} disabled={d.moving} onChange={e => d.setDraft(e.currentTarget.value)} placeholder="~/Documents/EurekaLife" error={!d.valid ? "请输入绝对路径或 ~/ 开头的目录" : undefined} />
      <div className="flex flex-wrap gap-[8px]"><Button variant="light" size="xs" disabled={d.moving} onClick={() => d.setDraft("~/Documents/EurekaLife")}>文稿目录</Button><Button variant="light" size="xs" disabled={d.moving} onClick={() => d.setDraft("/Volumes/Archive/EurekaLife")}>外置磁盘（示例）</Button></div>
      <div className="rounded-[8px] bg-[#fafafa] p-[16px] text-[13px] leading-[1.8]"><span className="text-[#8c8c8c]">当前位置</span><p className="mb-[12px] break-all">{d.path}</p><span className="text-[#8c8c8c]">迁移后</span><p className="mb-0 break-all">{d.clean || "请选择目录"}</p></div>
      {d.moving ? <Tag tone="primary">正在迁移并校验资料（演示）…</Tag> : <Alert status="waiting" title="路径选择与迁移均为原型演示，不读取或移动真实文件。" classNames={{ message: "whitespace-normal" }} />}
      <div className="flex justify-end gap-[12px]"><Button variant="subtle" disabled={d.moving} onClick={() => d.setOpened(false)}>取消</Button><Button disabled={!d.valid || d.clean === d.path || d.moving} onClick={d.change}>{d.moving ? "正在迁移…" : "迁移并使用新目录"}</Button></div>
    </div>
  </Modal>;
}
