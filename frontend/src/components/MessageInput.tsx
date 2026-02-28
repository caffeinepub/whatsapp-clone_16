import React, { useState, useRef } from 'react';
import { useSendMessage } from '../hooks/useQueries';
import { Send, Smile } from 'lucide-react';

interface MessageInputProps {
  conversationId: string;
}

export default function MessageInput({ conversationId }: MessageInputProps) {
  const [message, setMessage] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const sendMessage = useSendMessage(conversationId);

  const handleSend = async () => {
    const trimmed = message.trim();
    if (!trimmed || sendMessage.isPending) return;

    setMessage('');
    try {
      await sendMessage.mutateAsync(trimmed);
    } catch (err) {
      // Restore message on error
      setMessage(trimmed);
    }
    inputRef.current?.focus();
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="bg-sidebar-header px-4 py-3 flex items-center gap-3 shrink-0">
      <button className="p-2 rounded-full hover:bg-sidebar-hover text-sidebar-muted transition-colors shrink-0">
        <Smile className="w-5 h-5" />
      </button>

      <div className="flex-1 relative">
        <input
          ref={inputRef}
          type="text"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type a message"
          disabled={sendMessage.isPending}
          className="w-full px-4 py-2.5 rounded-xl bg-sidebar-hover text-sidebar-text placeholder:text-sidebar-muted text-sm focus:outline-none focus:ring-1 focus:ring-chat-sent disabled:opacity-60"
        />
      </div>

      <button
        onClick={handleSend}
        disabled={!message.trim() || sendMessage.isPending}
        className="p-2.5 rounded-full bg-chat-sent text-chat-sent-text hover:opacity-90 active:scale-95 transition-all disabled:opacity-40 disabled:cursor-not-allowed shrink-0"
        title="Send message"
      >
        {sendMessage.isPending ? (
          <svg className="animate-spin w-4 h-4" viewBox="0 0 24 24" fill="none">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
        ) : (
          <Send className="w-4 h-4" />
        )}
      </button>
    </div>
  );
}
