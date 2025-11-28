import { Alert, Button, Modal } from "react-bootstrap";

export const FormModal=({title, setShow,handleSubmit,children})=>{
          const handleClose=()=>{
                    setShow(0);
          }
          return(
                    <Modal show={true} onHide={handleClose}>
                            <Modal.Header closeButton>
                                    <Modal.Title>{title}</Modal.Title>
                            </Modal.Header>
                            <Modal.Body>
                                    {children}
                            </Modal.Body>
                            <Modal.Footer>
                            <Button variant="warning" onClick={handleClose}>Cancel</Button>
                            <Button variant="primary" onClick={handleSubmit}>Submit</Button>
                            </Modal.Footer>
                </Modal>
          )
}
export const ResultAlert=({alert,setShow})=>(
          <Alert show={true} variant={alert.variant}>
              <p>{alert.content}</p>
              <button type="button" className="close" aria-label="Close" onClick={()=>setShow(0)}></button>
          </Alert>
    )