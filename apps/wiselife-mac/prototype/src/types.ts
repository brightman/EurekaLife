export type Message = {
  role: "user" | "assistant";
  text: string;
  citations?: { id: string; label: string; time?: number }[];
};
export type Meeting = {
  id: string;
  title: string;
  date: string;
  time: string;
  duration: number;
  mode: string;
  language: string;
  source?: string;
  mic: boolean;
  system: boolean;
  screen: string;
  status: string;
  star: boolean;
  count: number;
  category: string;
  marks: number[];
  tasks: number[];
  messages: Message[];
  paused?: boolean;
  taskEdits?: Record<number, { task: string; owner: string; due: string }>;
};
export type KnowledgeRecord = {
  id: string;
  day: string;
  time: string;
  kind: string;
  title: string;
  summary: string;
  text: string;
  device: string;
  duration: string;
};
