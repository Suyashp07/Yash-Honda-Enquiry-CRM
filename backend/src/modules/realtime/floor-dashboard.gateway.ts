import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
  namespace: '/realtime/floor',
})
export class FloorDashboardGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(FloorDashboardGateway.name);

  handleConnection(client: Socket) {
    this.logger.log(`Floor Dashboard client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Floor Dashboard client disconnected: ${client.id}`);
  }

  @SubscribeMessage('rep:status_update')
  handleRepStatusUpdate(client: Socket, payload: { repId: string; status: 'Idle' | 'Busy'; branchCode: string }) {
    this.logger.log(`Rep status update: ${payload.repId} -> ${payload.status}`);
    // Broadcast live rep status change to all connected dashboard displays
    this.server.emit('rep:status_changed', {
      ...payload,
      updatedAt: new Date().toISOString(),
    });
  }

  // Method callable from any service (e.g. when an enquiry is opened/closed)
  broadcastRepStatus(repId: string, repName: string, branchCode: string, status: 'Idle' | 'Busy') {
    if (this.server) {
      this.server.emit('rep:status_changed', {
        repId,
        repName,
        branchCode,
        status,
        updatedAt: new Date().toISOString(),
      });
    }
  }
}
