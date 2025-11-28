import './App.css';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import ClientRouter from './Router/ClientRouter';
import AdminRouter from './Router/AdminRouter';
import { SnackbarProvider } from 'notistack';
import Login from './Page/Login';
import ProtectedRouter from './Router/ProtectedRouter';

function App() {
    return (
      <BrowserRouter>
      <SnackbarProvider maxSnack={3}>
          <Routes>
            <Route path="/login" element={<Login/>}/>
            <Route path="/admin/*" element={<ProtectedRouter requiredRole="ADMIN"><AdminRouter /></ProtectedRouter>}/>
            <Route path="/*" element={<ProtectedRouter requiredRole="STUDENT"><ClientRouter /></ProtectedRouter>}/>
        </Routes>
          </SnackbarProvider>
      </BrowserRouter>
  );
}

export default App;
